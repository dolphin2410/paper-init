use std::{io::Write, process::{Stdio, Command}};

use colored::Colorize;
use requestty::Question;

const COMPLEX: &[u8] = include_bytes!("../scripts/complex.sh");
const PAPER_WEIGHT: &[u8] = include_bytes!("../scripts/paperweight.sh");
const SETUP: &[u8] = include_bytes!("../scripts/setup.sh");
const GIT: &[u8] = include_bytes!("../scripts/git.sh");

#[derive(thiserror::Error, Debug)]
#[error("Invalid Project Name: {0}")]
struct InvalidProjectName(String);

fn request_project_name() -> String {
    let proj_name_q = Question::input("name")
        .message("Project Name?")
        .default(".")
        .build();

    let proj_name_a = requestty::prompt_one(proj_name_q).unwrap();

    let proj_name = validate_project_name(proj_name_a.as_string().unwrap());

    match proj_name {
        Ok(name) => {
            // run git clone command
            let mut file = std::fs::File::create("git.sh").unwrap();
            file.write_all(GIT).unwrap();

            std::process::Command::new("sh")
                .args(["git.sh", "https://github.com/dytroc/paper-sample", name.as_str()])
                .stdout(Stdio::inherit())
                .spawn()
                .unwrap()
                .wait()
                .unwrap();

            std::fs::remove_file("git.sh").unwrap();

            // remove scripts folder
            Command::new("rm")
                .args(["-rf", format!("{}/scripts", name).as_str()])
                .stdout(Stdio::inherit())
                .spawn()
                .unwrap()
                .wait()
                .unwrap();

            name
        },
        Err(error) => {
            let validation = error.downcast_ref::<InvalidProjectName>().unwrap();
            println!("{}: {}", "Invalid Project Name".red(), validation.0.truecolor(180, 180, 180));
            request_project_name()
        },
    }
}

fn request_project_type() -> String {
    let options = vec!["Default", "Complex", "PaperWeight"];
    let proj_type_q = Question::select("type")
        .message("Project Type?")
        .choices(options)
        .default(0)
        .build();

    requestty::prompt_one(proj_type_q).unwrap().as_list_item().unwrap().text.to_string()
}

fn run_file(data: &[u8], project_name: String) {
    let old = std::env::current_dir().unwrap();
    std::env::set_current_dir(project_name.clone()).unwrap();
    let mut file = std::fs::File::create("init.sh").unwrap();
    file.write_all(data).unwrap();
    let project_name = if project_name == "." {
        std::env::current_dir().unwrap().file_name().unwrap().to_str().unwrap().to_string()
    } else {
        project_name
    };
    std::process::Command::new("sh")
        .args(["init.sh", project_name.as_str()])
        .stdout(Stdio::inherit())
        .spawn()
        .unwrap()
        .wait()
        .unwrap();

    std::env::set_current_dir(old).unwrap();

    println!("The process has successfully finished...");
}

fn main() {
    let project_name = request_project_name();
    let project_type = request_project_type();

    match project_type.as_str() {
        "Default" => {
            run_file(SETUP, project_name);
        },
        "Complex" => {
            run_file(COMPLEX, project_name);
        },
        "PaperWeight" => {
            run_file(PAPER_WEIGHT, project_name);
        },
        _ => panic!("Invalid Value {}", project_name),
    }
}

fn validate_project_name(name: &str) -> Result<String, Box<dyn std::error::Error>> {
    let name = name.trim();
    if name.is_empty() {
        Err(InvalidProjectName("Project name cannot be empty".to_string()).into())
    } else if name.contains(':') {
        Err(InvalidProjectName("Project name cannot contain colons(:)".to_string()).into())
    } else {
        Ok(name.to_string())
    }
}