import os
import sys
import argparse
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom

def prettify_xml(elem):
    """Return a pretty-printed XML string."""
    rough_string = tostring(elem, 'utf-8')
    reparsed = minidom.parseString(rough_string)
    return reparsed.toprettyxml(indent="  ")

def generate_config_xml(repo_url, branch, jenkinsfile_path):
    flow_def = Element("flow-definition", {"plugin": "workflow-job"})

    SubElement(flow_def, "description").text = ""
    SubElement(flow_def, "keepDependencies").text = "false"

    definition = SubElement(
        flow_def,
        "definition",
        {"class": "org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition", "plugin": "workflow-cps"},
    )

    scm = SubElement(definition, "scm", {"class": "hudson.plugins.git.GitSCM", "plugin": "git"})
    SubElement(scm, "configVersion").text = "2"

    userRemoteConfigs = SubElement(scm, "userRemoteConfigs")
    userRemoteConfig = SubElement(userRemoteConfigs, "hudson.plugins.git.UserRemoteConfig")
    SubElement(userRemoteConfig, "url").text = repo_url

    branches = SubElement(scm, "branches")
    branchSpec = SubElement(branches, "hudson.plugins.git.BranchSpec")
    SubElement(branchSpec, "name").text = f"*/{branch}"

    SubElement(scm, "doGenerateSubmoduleConfigurations").text = "false"
    SubElement(scm, "submoduleCfg", {"class": "list"})
    SubElement(scm, "extensions")

    SubElement(definition, "scriptPath").text = jenkinsfile_path
    SubElement(definition, "lightweight").text = "true"

    SubElement(flow_def, "triggers")

    return prettify_xml(flow_def)

def main():
    parser = argparse.ArgumentParser(description="Generate Jenkins job XMLs for Jenkinsfiles in a path")
    parser.add_argument("--repo", required=True, help="Git repository URL (no auth)")
    parser.add_argument("--branch", required=True, help="Branch name")
    parser.add_argument("--path", required=True, help="Directory containing Jenkinsfiles")

    args = parser.parse_args()

    jenkinsfiles = [f for f in os.listdir(args.path) if f.startswith("Jenkinsfile")]
    if not jenkinsfiles:
        print("⚠️ No Jenkinsfiles found in given path.")
        sys.exit(1)

    for jf in jenkinsfiles:
        full_path = os.path.join(args.path, jf)
        rel_path = os.path.relpath(full_path, start=os.getcwd())  
        xml_content = generate_config_xml(args.repo, args.branch, rel_path)

        out_file = os.path.join(args.path, f"config_{jf}.xml")
        with open(out_file, "w") as f:
            f.write(xml_content)

        print(f"✅ Generated {out_file} for {jf}")

if __name__ == "__main__":
    main()
