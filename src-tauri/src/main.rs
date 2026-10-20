#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::process::Command;
use std::fs;
use std::path::PathBuf;
use tauri::{command, Manager, path::BaseDirectory};

fn resolve_engine_dir(app_handle: &tauri::AppHandle) -> Result<PathBuf, String> {
    if let Ok(path) = app_handle.path().resolve("resources/prometheus", BaseDirectory::Resource) {
        if path.exists() {
            return Ok(path);
        }
    }
    if let Ok(cwd) = std::env::current_dir() {
        let dev_path = cwd.join("src-tauri").join("resources").join("prometheus");
        if dev_path.exists() {
            return Ok(dev_path);
        }
    }
    Err("NullObfuscator: Internal error (missing components).".into())
}

fn find_lua_executable(resource_dir: &PathBuf) -> PathBuf {
    let lua_exe = resource_dir.join("lua.exe");
    if lua_exe.exists() {
        return lua_exe;
    }
    let luajit_exe = resource_dir.join("luajit.exe");
    if luajit_exe.exists() {
        return luajit_exe;
    }
    PathBuf::from("lua")
}

#[command]
async fn obfuscate_with_prometheus(app_handle: tauri::AppHandle, source: String, preset: String) -> Result<String, String> {
    let resource_dir = resolve_engine_dir(&app_handle)
        .map_err(|_| "NullObfuscator: Failed to initialize engine.".to_string())?;
    let cli_path = resource_dir.join("cli.lua");

    if !cli_path.exists() {
        return Err("NullObfuscator: Internal error (missing files).".into());
    }

    let lua_path = find_lua_executable(&resource_dir);

    let temp_dir = std::env::temp_dir();
    let openssl_bat = temp_dir.join("nullobf_openssl.bat");
    if !openssl_bat.exists() {
        let bat_content = "@echo off\r\necho 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\r\nexit /b 0\r\n";
        let _ = fs::write(&openssl_bat, bat_content);
    }

    let mut paths = std::env::var("PATH").unwrap_or_default();
    paths = format!("{};{};{}", temp_dir.to_string_lossy(), resource_dir.to_string_lossy(), paths);

    let input_path = temp_dir.join("__null_in.lua");
    let output_path = temp_dir.join("__null_out.lua");

    let _ = fs::remove_file(&output_path);
    fs::write(&input_path, &source)
        .map_err(|_| "NullObfuscator: Failed to write temporary file.".to_string())?;

    let output = Command::new(&lua_path)
        .current_dir(&resource_dir)
        .env("PATH", paths)
        .args([
            cli_path.to_str().unwrap(),
            "--LuaU",
            "--preset", &preset,
            "--out", output_path.to_str().unwrap(),
            input_path.to_str().unwrap(),
        ])
        .output()
        .map_err(|e| {
            eprintln!("[NullObfuscator] Internal Exec Error: {}", e);
            "NullObfuscator: Failed to start obfuscation process.".to_string()
        })?;

    let stderr = String::from_utf8_lossy(&output.stderr);

    if !output_path.exists() {
        let _ = fs::remove_file(&input_path);
        eprintln!("[NullObfuscator] Internal Obfuscation Error:\n{}", stderr);
        return Err("NullObfuscator: Obfuscation failed. Please check your code for syntax errors.".into());
    }

    let obfuscated = fs::read_to_string(&output_path)
        .map_err(|_| "NullObfuscator: Failed to read output file.".to_string())?;

    let _ = fs::remove_file(&input_path);
    let _ = fs::remove_file(&output_path);

    let banner = r#"--[[
    Null Obfuscator.
    
    https://github.com/ProjectNull-c
]]

"#;

    Ok(format!("{}{}", banner, obfuscated))
}

#[command]
fn save_file(content: String) -> Result<(), String> {
    let file_path = rfd::FileDialog::new()
        .add_filter("Luau / Lua", &["luau", "lua"])
        .set_file_name("obfuscated.lua")
        .save_file();

    if let Some(path) = file_path {
        fs::write(path, content).map_err(|e| format!("Failed to write file: {}", e))?;
        Ok(())
    } else {
        Err("Save cancelled".into())
    }
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            obfuscate_with_prometheus,
            save_file
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}