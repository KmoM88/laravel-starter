#!/usr/bin/env python3
import os
import sys
import requests

def usage():
    print(f"Usage: {sys.argv[0]} <JENKINS_URL> <USER> <API_TOKEN> <XML_DIR>")
    print("Example: python3 create_jobs.py http://192.168.0.10:8080 myuser mytoken ./jenkins_xml")
    sys.exit(1)

if len(sys.argv) != 5:
    usage()

JENKINS_URL = sys.argv[1].rstrip('/')
USER = sys.argv[2]
API_TOKEN = sys.argv[3]
XML_DIR = sys.argv[4]

if not os.path.isdir(XML_DIR):
    print(f"Error: {XML_DIR} is not a directory")
    sys.exit(1)

for filename in os.listdir(XML_DIR):
    if filename.endswith('.xml') and filename.startswith('config_Jenkinsfile.'):
        # Extraer nombre del job
        job_name = filename[len('config_Jenkinsfile.'):].replace('.xml', '')
        xml_path = os.path.join(XML_DIR, filename)

        with open(xml_path, 'rb') as f:
            xml_data = f.read()

        create_url = f"{JENKINS_URL}/createItem?name={job_name}"
        headers = {'Content-Type': 'application/xml'}

        print(f"Creating job '{job_name}' from {filename}...")
        response = requests.post(create_url, auth=(USER, API_TOKEN), headers=headers, data=xml_data)

        if response.status_code == 200:
            print(f"✅ Job '{job_name}' created successfully.")
        elif response.status_code == 400:
            print(f"⚠️ Job '{job_name}' already exists.")
        else:
            print(f"❌ Failed to create job '{job_name}': {response.status_code} {response.text}")
