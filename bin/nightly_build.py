#!/usr/bin/python3
"""
Python Regression Build Automation Script

This Python script serves the purpose of automating nightly regression builds for a software project. 
The script is designed to handle the setup, execution, and reporting aspects of the regression testing process.

Features:

    1.  Nightly Regression Builds: The script is scheduled to run on a nightly basis, making and executing the regression builds.

    2.  Markdown Report Generation: Upon completion of the regression tests, the script generates detailed reports in Markdown format. 
        These reports provide comprehensive insights into the test results, including test cases executed, pass/fail status, and any encountered issues.    

    3.  Email Notification: The script is configured to send out email notifications summarizing the regression test results. 
        These emails serve as communication channels for stakeholders, providing them with timely updates on the software's regression status.

Usage:

- The script is designed to be scheduled and executed automatically on a nightly basis using task scheduling tools such as Cronjobs. To create a cronjob do the following:
    1)  Open Terminal:

        Open your terminal application. This is where you'll enter the commands to create and manage cron jobs.

    2)  Access the Cron Table:

        Type the following command and press Enter:

        crontab -e

        This command opens the crontab file in your default text editor. If it's your first time, you might be prompted to choose a text editor.

    3)  Edit the Cron Table:
        The crontab file will open in your text editor. Each line in this file represents a cron job. You can now add your new cron job.

    4)  Syntax:

        Our cron job has the following syntax:
        0 3 * * * BASH_ENV=~/.bashrc bash -l -c "*WHERE YOUR CVW IS MUST PUT FULL PATH*/cvw/bin/wrapper_nightly_runs.sh > *WHERE YOU WANT TO STORE LOG FILES/cron.log 2>&1" 

        This cronjob sources the .bashrc file and executes the wrapper script as a user. 

    5)  Double check:

        Execute the following command to see your cronjobs:
        
        crontab -l

Dependencies:
    Python:
        - os
        - shutil
        - datetime from datetime
        - re
        - markdown
        - subprocess

    Bash:
        - mutt (email sender)

Conclusion:

In summary, this Python script facilitates the automation of nightly regression builds, providing comprehensive reporting and email notification capabilities to ensure effective communication and monitoring of regression test results.
"""

import os
import shutil
from datetime import datetime
import re
import markdown
import subprocess



class FolderManager:
    """A class for managing folders and repository cloning."""

    def __init__(self):
        """
        Initialize the FolderManager instance.

        Args:
            base_dir (str): The base directory where folders will be managed and repository will be cloned.
        """
        env_extract_var = 'WALLY'
        print(f"The environemntal variable is {env_extract_var}")
        self.base_dir = os.environ.get(env_extract_var)
        print(f"The base directory is: {self.base_dir}")
        self.base_parent_dir = os.path.dirname(self.base_dir)

        # print(f"The new WALLY vairable is: {os.environ.get('WALLY')}")
        # print(f"The Base Directory is now : {self.base_dir}")
        # print(f"The Base Parent Directory is now : {self.base_parent_dir}")

    def create_preliminary_folders(self, folders):
        """
        Create preliminary folders if they do not exist. 
        These folders are:
            nightly_runs/repos/
            nightly_runs/results/ 

        Args:
            folders (list): A list of folder names to be created.

        Returns:
            None
        """
        
        for folder in folders:
            folder_path = os.path.join(self.base_parent_dir, folder)
            if not os.path.exists(folder_path):
                os.makedirs(folder_path)

    def create_new_folder(self, folders):
        """
        Create a new folder based on the current date if it does not already exist.

        Args:
            folder_name (str): The base name for the new folder.

        Returns:
            str: The path of the newly created folder if created, None otherwise.
        """

        todays_date = datetime.now().strftime("%Y-%m-%d")
        return_folder_path = []
        for folder in folders:
            folder_path = os.path.join(self.base_parent_dir, folder, todays_date)
            if not os.path.exists(folder_path):
                os.makedirs(folder_path)
                return_folder_path.append(folder_path)
            else:
                return_folder_path.append(None) # Folder already exists
        
        return return_folder_path

    def clone_repository(self, folder, repo_url):
        """
        Clone a repository into the 'cvw' folder if it does not already exist.

        Args:
            repo_url (str): The URL of the repository to be cloned.

        Returns:
            None
        """
        todays_date = datetime.now().strftime("%Y-%m-%d")
        repo_folder = os.path.join(self.base_parent_dir, folder, todays_date, 'cvw')
        tmp_folder = os.path.join(repo_folder, "tmp") # temprorary files will be stored in here

        if not os.path.exists(repo_folder):
            os.makedirs(repo_folder)
            os.system(f"git clone --recurse-submodules {repo_url} {repo_folder}")
            os.makedirs(tmp_folder)
    

class TestRunner:
    """A class for making, running, and formatting test results."""

    def __init__(self): 
        self.base_dir = os.environ.get('WALLY')
        self.base_parent_dir = os.path.dirname(self.base_dir)
        self.current_datetime = datetime.now()
        #self.temp_dir = self.base_parent_dir
        #print(f"Base Directory: {self.base_parent_dir}")
        
    def copy_setup_script(self, folder):
        """
        Copy the setup script to the destination folder.

        The setup script will be copied from the base directory to a specific folder structure inside the base directory.

        Args:
            folder: the "nightly_runs/repos/"

        Returns:
            bool: True if the script is copied successfully, False otherwise.
        """
        # Get today's date in YYYY-MM-DD format
        todays_date = datetime.now().strftime("%Y-%m-%d")

        # Define the source and destination paths
        source_script = os.path.join(self.base_dir, "setup_host.sh")
        destination_folder = os.path.join(self.base_parent_dir, folder, todays_date, 'cvw')
        
        # Check if the source script exists
        if not os.path.exists(source_script):
            print(f"Error: Source script '{source_script}' not found.")
            return False


        # Check if the destination folder exists, create it if necessary
        if not os.path.exists(destination_folder):
            print(f"Error: Destination folder '{destination_folder}' not found.")
            return False

        # Copy the script to the destination folder
        try:
            shutil.copy(source_script, destination_folder)
            #print(f"Setup script copied to: {destination_folder}")
            return True
        except Exception as e:
            print(f"Error copying setup script: {e}")
            return False


    def set_env_var(self, folder):
        """
        Source a shell script.

        Args:
            script_path (str): Path to the script to be sourced.

        Returns:
            None
        """
        # find the new repository made
        todays_date = datetime.now().strftime("%Y-%m-%d")
        wally_path = os.path.join(self.base_parent_dir, folder, todays_date, 'cvw')

        # set the WALLY environmental variable to the new repository
        os.environ["WALLY"] = wally_path

        self.base_dir = os.environ.get('WALLY')
        self.base_parent_dir = os.path.dirname(self.base_dir)
        self.temp_dir = self.base_parent_dir

        # print(f"The new WALLY vairable is: {os.environ.get('WALLY')}")
        # print(f"The Base Directory is now : {self.base_dir}")
        # print(f"The Base Parent Directory is now : {self.base_parent_dir}")
       
    def execute_makefile(self, target=None):
        """
        Execute a Makefile with optional target.

        Args:
            makefile_path (str): Path to the Makefile.
            target (str, optional): Target to execute in the Makefile.

        Returns:
            True if the tests were made
            False if the tests didnt pass
        """
        # Prepare the command to execute the Makefile
        make_file_path = os.path.join(self.base_dir, "sim")
        os.chdir(make_file_path)

        output_file = os.path.join(self.base_dir, "tmp", "make_output.log")

        command = ["make"]

        # Add target to the command if specified
        if target:
            command.append(target)
        #print(f"The command is: {command}")

        # Execute the command using subprocess and save the output into a file
        with open(output_file, "w") as f:
            formatted_datetime = self.current_datetime.strftime("%Y-%m-%d %H:%M:%S")
            f.write(formatted_datetime)
            f.write("\n\n")
            result = subprocess.run(command, stdout=f, stderr=subprocess.STDOUT, text=True)
        
        # Execute the command using a subprocess and not save the output
        #result = subprocess.run(command, text=True)

        # Check the result
        if result.returncode == 0:
            #print(f"Makefile executed successfully{' with target ' + target if target else ''}.")
            return True
        else:
            #print("Error executing Makefile.")
            return False
            
    def run_tests(self, test_type=None, test_name=None, test_exctention=None):
        """
        Run a script through the terminal and save the output to a file.

        Args:
            test_name (str): The test name will allow the function to know what test to execute in the sim directory
            test_type (str): The type such as python, bash, etc
        Returns:
            True and the output file location
        """

        # Prepare the function to execute the simulation
        test_file_path = os.path.join(self.base_dir, "sim")
        
        output_file = os.path.join(self.base_dir, "tmp", f"{test_name}-output.log")
        os.chdir(test_file_path)

        if test_exctention:
            command = [test_type, test_name, test_exctention]
        else:
            command = [test_type, test_name]

        # Execute the command using subprocess and save the output into a file
        with open(output_file, "w") as f:
            formatted_datetime = self.current_datetime.strftime("%Y-%m-%d %H:%M:%S")
            f.write(formatted_datetime)
            f.write("\n\n")
            result = subprocess.run(command, stdout=f, stderr=subprocess.STDOUT, text=True)
        
        # Check if the command executed successfully
        if result.returncode or result.returncode == 0:
            return True, output_file
        else:
            print("Error:", result.returncode)
            return False, output_file


    def clean_format_output(self, input_file, output_file=None):
        """
        Clean and format the output from tests.

        Args:
            input_file (str): Path to the input file with raw test results.
            output_file (str): Path to the file where cleaned and formatted output will be saved.

        Returns:
            None
        """
        # Implement cleaning and formatting logic here

        # Open up the file with only read permissions
        with open(input_file, 'r') as input_file:
            unlceaned_output = input_file.read()

        # use something like this function to detect pass and fail
        passed_configs = []
        failed_configs = []

        lines = unlceaned_output.split('\n')
        index = 0

        while index < len(lines):
            # Remove ANSI escape codes
            line = re.sub(r'\x1b\[[0-9;]*[mGK]', '', lines[index])  
            #print(line)
            if "Success" in line:
                passed_configs.append(line.split(':')[0].strip())
            elif "passed lint" in line:
                #print(line)
                passed_configs.append(line.split(' ')[0].strip())
                #passed_configs.append(line) # potentially use a space
            elif "failed lint" in line:
                failed_configs.append(line.split(' ')[0].strip(), "no log file")
                #failed_configs.append(line)

            elif "Failures detected in output" in line:
                try:
                    config_name = line.split(':')[0].strip()
                    log_file = os.path.abspath("logs/"+config_name+".log")
                    #print(f"The log file saving to: {log_file} in the current working directory: {os.getcwd()}") 
                    failed_configs.append((config_name, log_file))
                except:
                    failed_configs.append((config_name, "Log file not found"))
            

            index += 1

        # alphabetically sort the configurations
        if len(passed_configs) != 0:
            passed_configs.sort()

        if len(failed_configs) != 0:
            failed_configs.sort()
        #print(f"The passed configs are: {passed_configs}")
        #print(f"The failed configs are {failed_configs}")
        return passed_configs, failed_configs

    def rewrite_to_markdown(self, test_name, passed_configs, failed_configs):
        """
        Rewrite test results to markdown format.

        Args:
            input_file (str): Path to the input file with cleaned and formatted output.
            markdown_file (str): Path to the markdown file where test results will be saved.

        Returns:
            None
        """
        # Implement markdown rewriting logic here
        timestamp = datetime.now().strftime("%Y-%m-%d")

        output_directory = os.path.join(self.base_parent_dir, "../../results", timestamp)
        os.chdir(output_directory)
        current_directory = os.getcwd()
        output_file = os.path.join(current_directory, f"{test_name}.md")
        #print("Current directory:", current_directory)
        #print("Output File:", output_file)

        with open(output_file, 'w') as md_file:
       
            # Title
            md_file.write(f"\n\n# Regression Test Results - {timestamp}\n\n")
            #md_file.write(f"\n\n<div class=\"regression\">\n# Regression Test Results - {timestamp}\n</div>\n\n")

            # File Path
            md_file.write(f"\n**File:** {output_file}\n\n")

            if failed_configs:
                md_file.write("## Failed Configurations\n\n")
                for config, log_file in failed_configs:
                    md_file.write(f"- <span class=\"failure\" style=\"color: red;\">{config}</span> ({log_file})\n")
                md_file.write("\n")
            else:
                md_file.write("## Failed Configurations\n")
                md_file.write(f"No Failures\n")
            
            md_file.write("\n## Passed Configurations\n")
            for config in passed_configs:
                md_file.write(f"- <span class=\"success\" style=\"color: green;\">{config}</span>\n")

    def combine_markdown_files(self, passed_tests, failed_tests, test_list, total_number_failures, total_number_success, test_type="default", markdown_file=None):
        """
        First we want to display the server properties like:
            - Server full name
            - Operating System

        Combine the markdown files and format them to display all of the failures at the top categorized by what kind of test it was
        Then display all of the successes.

        Args:
            passed_tests (list): a list of successful tests
            failed_tests (list): a list of failed tests
            test_list (list): a list of the test names. 
            markdown_file (str): Path to the markdown file where test results will be saved.

        Returns:
            None
        """
        timestamp = datetime.now().strftime("%Y-%m-%d")

        output_directory = os.path.join(self.base_parent_dir, "../../results", timestamp)
        os.chdir(output_directory)
        current_directory = os.getcwd()
        output_file = os.path.join(current_directory, "results.md")
        

        with open(output_file, 'w') as md_file:
            # Title
            md_file.write(f"\n\n# Nightly Test Results - {timestamp}\n\n")
            # Host information
            try:
                # Run hostname command
                hostname = subprocess.check_output(['hostname', '-A']).strip().decode('utf-8')
                md_file.write(f"**Host name:** {hostname}")
                md_file.write("\n")
                # Run uname command to get OS information
                os_info = subprocess.check_output(['uname', '-a']).strip().decode('utf-8')
                md_file.write(f"\n**Operating System Information:** {os_info}")
                md_file.write("\n")
            except subprocess.CalledProcessError as e:
                # Handle if the command fails
                md_file.write(f"Failed to identify host and Operating System information: {str(e)}")
            
            # Which tests did we run
            md_file.write(f"\n**Tests made:** `make {test_type}`\n")

            # File Path
            md_file.write(f"\n**File:** {output_file}\n\n") # *** needs to be changed
            md_file.write(f"**Total Successes: {total_number_success}**\n")
            md_file.write(f"**Total Failures: {total_number_failures}**\n")

            # Failed Tests
            md_file.write(f"\n\n## Failed Tests")
            md_file.write(f"\nTotal failed tests: {total_number_failures}")
            for (test_item, item) in zip(test_list, failed_tests):
                md_file.write(f"\n\n### {test_item[1]} test")
                md_file.write(f"\n**General Information**\n")
                md_file.write(f"\n* Test type: {test_item[0]}\n")
                md_file.write(f"\n* Test name: {test_item[1]}\n")
                md_file.write(f"\n* Test extension: {test_item[2]}\n\n")
                md_file.write(f"**Failed Tests:**\n")

                

                if len(item) == 0:
                    md_file.write("\n")
                    md_file.write(f"* <span class=\"no-failure\" style=\"color: green;\">No failures</span>\n")
                    md_file.write("\n")
                else:
                    for failed_test in item:
                        config = failed_test[0]
                        log_file = failed_test[1]

                        md_file.write("\n")
                        md_file.write(f"* <span class=\"failure\" style=\"color: red;\">{config}</span> ({log_file})\n")
                        md_file.write("\n")
            # Successfull Tests

            md_file.write(f"\n\n## Successfull Tests")
            md_file.write(f"\n**Total successfull tests: {total_number_success}**")
            for (test_item, item) in zip(test_list, passed_tests):
                md_file.write(f"\n\n### {test_item[1]} test")
                md_file.write(f"\n**General Information**\n")
                md_file.write(f"\n* Test type: {test_item[0]}")
                md_file.write(f"\n* Test name: {test_item[1]}")
                md_file.write(f"\n* Test extension: {test_item[2]}\n\n")
                md_file.write(f"\n**Successfull Tests:**\n")

                

                if len(item) == 0:
                    md_file.write("\n")
                    md_file.write(f"* <span class=\"no-successes\" style=\"color: red;\">No successes</span>\n")
                    md_file.write("\n")
                else:
                    for passed_tests in item:
                        config = passed_tests
                        
                        md_file.write("\n")
                        md_file.write(f"* <span class=\"success\" style=\"color: green;\">{config}</span>\n")
                        md_file.write("\n")
                    
                    

    def convert_to_html(self, markdown_file="results.md", html_file="results.html"):
        """
        Convert markdown file to HTML.

        Args:
            markdown_file (str): Path to the markdown file.
            html_file (str): Path to the HTML file where converted output will be saved.

        Returns:
            None
        """
        # Implement markdown to HTML conversion logic here
        todays_date = self.current_datetime.strftime("%Y-%m-%d")
        markdown_file_path = os.path.join(self.base_parent_dir, "../../results", todays_date) 
        os.chdir(markdown_file_path)

        with open(markdown_file, 'r') as md_file:
            md_content = md_file.read()
            html_content = markdown.markdown(md_content)
        
        with open(html_file, 'w') as html_file:
            html_file.write(html_content)
        

 
    def send_email(self, sender_email=None, receiver_emails=None, subject="Nightly Regression Test"):
        """
        Send email with HTML content.

        Args:
            self: The instance of the class.
            sender_email (str): The sender's email address. Defaults to None.
            receiver_emails (list[str]): List of receiver email addresses. Defaults to None.
            subject (str, optional): Subject of the email. Defaults to "Nightly Regression Test".

        Returns:
            None
        """

        # check if there are any emails
        if not receiver_emails:
            print("No receiver emails provided.")
            return
        # grab thge html file
        todays_date = self.current_datetime.strftime("%Y-%m-%d")
        html_file_path = os.path.join(self.base_parent_dir, "../../results", todays_date) 
        os.chdir(html_file_path)
        html_file = "results.html"

        with open(html_file, 'r') as html_file:
                body = html_file.read()

    
        

        for receiver_email in receiver_emails:
            # Compose the mutt command for each receiver email
            command = [
                'mutt',
                '-s', subject,
                '-e', 'set content_type=text/html',
                '-e', 'my_hdr From: James Stine <james.stine@okstate.edu>',
                '--', receiver_email
            ]
            
            # Open a subprocess to run the mutt command
            process = subprocess.Popen(command, stdin=subprocess.PIPE)
            
            # Write the email body to the subprocess
            process.communicate(body.encode('utf-8'))


#############################################
#                 SETUP                     #
#############################################
folder_manager = FolderManager() # creates the object

# setting the path on where to clone new repositories of cvw
path = folder_manager.create_preliminary_folders(["nightly_runs/repos/", "nightly_runs/results/"])
new_folder = folder_manager.create_new_folder(["nightly_runs/repos/", "nightly_runs/results/"])

# clone the cvw repo
folder_manager.clone_repository("nightly_runs/repos/", "https://github.com/openhwgroup/cvw.git")


        
#############################################
#                 SETUP                     #
#############################################

test_runner = TestRunner() # creates the object
test_runner.set_env_var("nightly_runs/repos/") # ensures that the new WALLY environmental variable is set correctly


#############################################
#              MAKE TESTS                   #
#############################################


# target = "wally-riscv-arch-test"
target = "all"
if test_runner.execute_makefile(target = target):
   print(f"The {target} tests were made successfully")

#############################################
#               RUN TESTS                   #
#############################################


test_list = [["python", "regression-wally", "-nightly"], ["bash", "lint-wally", "-nightly"], ["bash", "coverage", "--search"]]
output_log_list = [] # a list where the output markdown file lcoations will be saved to
total_number_failures = 0  # an integer where the total number failures from all of the tests will be collected
total_number_success = 0    # an integer where the total number of sucess will be collected

total_failures = []
total_success = []

for test_type, test_name, test_exctention in test_list:
    print("--------------------------------------------------------------")
    print(f"Test type: {test_type}")
    print(f"Test name: {test_name}")
    print(f"Test extenction: {test_exctention}")

    check, output_location = test_runner.run_tests(test_type=test_type, test_name=test_name, test_exctention=test_exctention)
    print(check)
    print(output_location)
    if check: # this checks if the test actually ran successfully
        output_log_list.append(output_location)
        
        # format tests to markdown
        try:
            passed, failed = test_runner.clean_format_output(input_file = output_location)
        except:
            print("There was an error cleaning the data")

        print(f"The # of failures are for {test_name}: {len(failed)}")
        total_number_failures+= len(failed)
        total_failures.append(failed)

        print(f"The # of sucesses are for {test_name}: {len(passed)}")
        total_number_success += len(passed)
        total_success.append(passed)
        test_runner.rewrite_to_markdown(test_name, passed, failed)

print(f"The total sucesses are: {total_number_success}")
print(f"The total failures are: {total_number_failures}")




    

#############################################
#               FORMAT TESTS                #
#############################################

# Combine multiple markdown files into one file

test_runner.combine_markdown_files(passed_tests = total_success, failed_tests = total_failures, test_list = test_list, total_number_failures = total_number_failures, total_number_success = total_number_success, test_type=target, markdown_file=None)


#############################################
#             WRITE MD TESTS                #
#############################################
test_runner.convert_to_html()



#############################################
#                SEND EMAIL                 #
#############################################

sender_email = 'james.stine@okstate.edu'
receiver_emails = ['thomas.kidd@okstate.edu', 'james.stine@okstate.edu', 'harris@g.hmc.edu', 'rose.thompson10@okstate.edu']
test_runner.send_email(sender_email=sender_email, receiver_emails=receiver_emails)