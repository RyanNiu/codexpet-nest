use crate::app_config::AppConfig;
use serde::{Deserialize, Serialize};
use tauri::{AppHandle, State};
use tauri_plugin_opener::OpenerExt;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QuickActionRequest {
    pub id: String,
    #[serde(rename = "type")]
    pub action_type: String,
    pub target: String,
    pub platform: Option<String>,
    pub enabled: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct QuickActionResult {
    pub id: String,
    pub status: String,
    pub message: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ActionCapabilities {
    pub platform: String,
    pub supported_action_types: Vec<String>,
    pub disabled_action_types: Vec<String>,
    pub allowlisted_url_prefixes: Vec<String>,
    pub allowlisted_app_targets: Vec<String>,
    pub shell_execution_enabled: bool,
}

#[tauri::command]
pub fn get_action_capabilities(config: State<'_, AppConfig>) -> Result<ActionCapabilities, String> {
    Ok(action_capabilities(config.platform.clone()))
}

#[tauri::command]
pub fn list_supported_actions(config: State<'_, AppConfig>) -> Result<ActionCapabilities, String> {
    Ok(action_capabilities(config.platform.clone()))
}

#[tauri::command]
pub fn execute_quick_action(
    app: AppHandle,
    config: State<'_, AppConfig>,
    action: QuickActionRequest,
) -> Result<QuickActionResult, String> {
    validate_action(&action, &config.platform)?;

    match action.action_type.as_str() {
        "url" => {
            app.opener()
                .open_url(action.target.clone(), None::<&str>)
                .map_err(|error| format!("Failed to open URL: {}", error))?;
            Ok(result(
                action.id,
                "opened",
                "URL opened with system browser",
            ))
        }
        "shortcut" => Ok(result(
            action.id,
            "mocked",
            "Shortcut placeholder completed safely",
        )),
        "app" => Ok(result(
            action.id,
            "mocked",
            "App/path open is a Phase 7 placeholder",
        )),
        "shell-placeholder" => Err(
            "shell-placeholder is disabled; arbitrary shell execution is not supported".to_string(),
        ),
        other => Err(format!("Unsupported action type: {}", other)),
    }
}

fn action_capabilities(platform: String) -> ActionCapabilities {
    ActionCapabilities {
        platform,
        supported_action_types: vec!["url".into(), "app".into(), "shortcut".into()],
        disabled_action_types: vec!["shell-placeholder".into()],
        allowlisted_url_prefixes: vec!["https://codexpet.xyz/".into(), "http://localhost:".into()],
        allowlisted_app_targets: vec!["codex-home".into()],
        shell_execution_enabled: false,
    }
}

fn validate_action(action: &QuickActionRequest, platform: &str) -> Result<(), String> {
    if !action.enabled {
        return Err(format!("Action {} is disabled", action.id));
    }
    if let Some(action_platform) = &action.platform {
        if action_platform != "all" && action_platform != platform {
            return Err(format!(
                "Action {} is not supported on platform {}",
                action.id, platform
            ));
        }
    }

    match action.action_type.as_str() {
        "url" => validate_url_target(&action.target),
        "shortcut" => validate_shortcut_target(&action.target),
        "app" => validate_app_target(&action.target),
        "shell-placeholder" => Err(
            "shell-placeholder is disabled; arbitrary shell execution is not supported".to_string(),
        ),
        other => Err(format!("Unsupported action type: {}", other)),
    }
}

fn validate_url_target(target: &str) -> Result<(), String> {
    if target.starts_with("https://codexpet.xyz/") || target.starts_with("http://localhost:") {
        Ok(())
    } else {
        Err(format!("URL target is not allowlisted: {}", target))
    }
}

fn validate_shortcut_target(target: &str) -> Result<(), String> {
    if target == "copy:https://codexpet.xyz/docs" || target == "open-docs-placeholder" {
        Ok(())
    } else {
        Err(format!("Shortcut target is not allowlisted: {}", target))
    }
}

fn validate_app_target(target: &str) -> Result<(), String> {
    if target == "codex-home" {
        Ok(())
    } else {
        Err(format!("App/path target is not allowlisted: {}", target))
    }
}

fn result(id: String, status: &str, message: &str) -> QuickActionResult {
    QuickActionResult {
        id,
        status: status.to_string(),
        message: message.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_shell_placeholder() {
        let action = QuickActionRequest {
            id: "shell".into(),
            action_type: "shell-placeholder".into(),
            target: "echo nope".into(),
            platform: Some("all".into()),
            enabled: true,
        };

        assert!(validate_action(&action, "macos").is_err());
    }

    #[test]
    fn rejects_unsupported_platform() {
        let action = QuickActionRequest {
            id: "mac-only".into(),
            action_type: "url".into(),
            target: "https://codexpet.xyz/docs".into(),
            platform: Some("macos".into()),
            enabled: true,
        };

        assert!(validate_action(&action, "linux").is_err());
    }

    #[test]
    fn rejects_non_allowlisted_url() {
        let action = QuickActionRequest {
            id: "bad-url".into(),
            action_type: "url".into(),
            target: "file:///tmp/secret".into(),
            platform: Some("all".into()),
            enabled: true,
        };

        assert!(validate_action(&action, "macos").is_err());
    }

    #[test]
    fn accepts_allowlisted_placeholders() {
        let shortcut = QuickActionRequest {
            id: "copy".into(),
            action_type: "shortcut".into(),
            target: "copy:https://codexpet.xyz/docs".into(),
            platform: Some("all".into()),
            enabled: true,
        };
        let app = QuickActionRequest {
            id: "codex".into(),
            action_type: "app".into(),
            target: "codex-home".into(),
            platform: Some("all".into()),
            enabled: true,
        };

        assert!(validate_action(&shortcut, "macos").is_ok());
        assert!(validate_action(&app, "macos").is_ok());
    }

    #[test]
    fn default_capability_does_not_grant_shell() {
        let capability = include_str!("../../capabilities/default.json");

        assert!(!capability.contains("shell:default"));
    }
}
