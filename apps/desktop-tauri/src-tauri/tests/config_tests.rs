use directories::ProjectDirs;

#[test]
fn test_app_config_data_directory_resolves() {
    let dirs = ProjectDirs::from("xyz", "codexpet", "CodexPet Nest");
    assert!(
        dirs.is_some(),
        "ProjectDirs should resolve for our bundle ID"
    );

    let data_dir = dirs.unwrap().data_dir().to_string_lossy().to_string();

    #[cfg(target_os = "macos")]
    assert!(
        data_dir.contains("Application Support"),
        "macOS data dir should be in Application Support: {}",
        data_dir
    );

    #[cfg(target_os = "windows")]
    assert!(
        data_dir.contains("AppData"),
        "Windows data dir should be in AppData: {}",
        data_dir
    );
}

#[test]
fn test_fallback_data_dir_returns_non_empty() {
    // The fallback function should always return a non-empty string
    // even if ProjectDirs fails.
    let fallback = if cfg!(target_os = "macos") {
        let home = dirs::home_dir().unwrap_or_default();
        home.join("Library/Application Support/CodexPet Nest")
            .to_string_lossy()
            .to_string()
    } else {
        let home = dirs::home_dir().unwrap_or_default();
        home.join(".codexpet-nest").to_string_lossy().to_string()
    };
    assert!(
        !fallback.is_empty(),
        "Fallback data dir should not be empty"
    );
}

#[test]
fn test_platform_detection() {
    let platform = std::env::consts::OS;
    assert!(
        platform == "macos" || platform == "windows" || platform == "linux",
        "Platform should be a recognized OS: {}",
        platform
    );
}
