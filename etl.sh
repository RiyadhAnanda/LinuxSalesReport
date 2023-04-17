#!/bin/bash
# Name: Riyadh Ananda
# Date: 12-09-2022
# Project: Semester Project

#*****************************************
# Script Purpose
# This script imports a file, uncompresses the file, preprocesses the data
# (clean the data), sums the amount of purchases by state for only
# Female and Male to figure out what state had the most purchases as well as
# sum the total of purchases by gender for each state to find out which genders donated the most by each state
#*****************************************

# Err Handling
set -o errexit # exit if an error occurs
set -o pipefail #exit if error occurs during pipes

# Check parameters are correct
if (( $# != 3 )); then
	echo "Usage: $0 file fname lname" ; exit 1
fi

# Check to make sure user inputted "MOCK_MIX_v2.csv"
if [[ $1 != 'MOCK_MIX_v2.1.csv' ]]; then
	echo "First parameter must be 'MOCK_MIX_csv.bz2' (\$1)($1)"; exit 1
fi

# Declare Variables
remote_file="$1"
remote_usrid=""
remote_server=""
src_file_compressed="$(basename $remote_file)"
src_file_extracted=""
fname="$2"
lname="$3"

# Function to remove tmp files and clean up directory after runnning script
function rm_temps () {
	read -p "Delete Temporary Files? (Y/n):"
	if [[ $REPLY = [Yy] ]]; then
		rm -f *.tmp
		rm -f Demo*
		echo "Temporary Files Deleted"
	fi
}

# Function to remove csv files and clean up directory after running scripts
function rm_csv () {
	read -p "Delete CSV Files? (Y/n):"
	if [[ $REPLY = [Yy] ]]; then
		rm -f *.csv
		echo "CSV Files Deleted"
 	fi
}

#Function to remove rpt files
function rm_MOCK () {
	read -p "Delete MOCK File? Necessary to repeat (Y/n):"
	if [[ $REPLY = [Yy] ]]; then
		rm -f *.1.csv
		echo "MOCK File Deleted"
	fi
}
	
# Function for pulling MOCK_MIX_v2.1.csv.bz2 file from server
function extractcsv_file (){
	# Prompt if user would like to extract the file
	read -p "Would You like to pull the MOCK_MIX File? (Y/n): "
	if [[ $REPLY = [Yy] ]]; then
	# scp command to copy file from server to local semester_project directory
	#scp ${2}@${1}:${3} ~/semester_project
	scp class-srv:/home/shared/MOCK_MIX_v2.1.csv.bz2 ~/semester_project
	# bunzip2 removes or unzips .bz2 from the MOCK_MIX file
	bunzip2 MOCK_MIX_v2.1.csv.bz2
	# echo 'File Copied' in order to assure the function ran properly
	echo "File succesfully copied and unzipped"
	fi
	}

#Call extractcsv file 
extractcsv_file	


	# 1) Remove the header from the MOCK_MIX_v2_1
	tail -n +2 "$remote_file" > "01_rm_header.tmp"
	printf "1) Removed header from file -- complete\n"

	# 2) Convert all text to lower case
	tr '[:upper:]' '[:lower:]' < "01_rm_header.tmp" > "02_conv_lower.tmp"
	printf "2) Converted all text to lowercase -- complete\n"

	# 3) Convert gender to just "f" and "m" by calling _convert_gender.awk and place into 03_conv_gender.tmp
	printf "3) Converted gender values to m/f exclusively -- complete\n"
	gawk -f "scripts/_convert_gender.awk" "02_conv_lower.tmp" > "03_conv_gender.tmp"
	
	# 4) Filter out all records that do not contain a state field or contain "NA" and extract to exceptions.csv using external script
	# _filter_statefield.awk
	printf "4) Filter out all records that don't contain a valid state -- complete\n"
	#Using _filter_exceptions.awk, place all values without a state field into exceptions.csv
	gawk -f "scripts/_filter_exceptions.awk" "03_conv_gender.tmp" > "exceptions.csv"
	#Using _filter_statefield.awk, place all values with a valid state field into 04_filtered_statefield.tmp
	gawk -f "scripts/_filter_statefield.awk" "03_conv_gender.tmp" > "04_filtered_statefield.tmp"

	# 5) Remove the $ sign in the transaction file from the purchase_amt field
	printf "5) Remove the $ sign in the transcation file from purchase_amt -- complete\n"
	# Call signrm.awk, input the data from 04_filtered_statefield.tmp which has valid states and output to rmsign.csv
	gawk -f "scripts/signrm.awk" "04_filtered_statefield.tmp" > "rmsign.csv"
	# Since rmsign.csv is a submission file, copy its contents into 05_removed_sign.tmp for further data manipulation
	cp "rmsign.csv" "05_removed_sign.tmp"

	# 6) Sort transaction file by customerID
	printf "6) Sort the transaction file based on customerID -- complete\n"
	#sort on field 1 customerID from the most recent datamanip file which is 05_removed_sign.tmp and place into submission file transaction.csv
	sort -t ',' -k 1 "05_removed_sign.tmp" > "transaction.csv"
	
	#7) Summary File Generation
	printf "7) Creating summary.csv file -- complete\n"
	# Call summary_organize.awk, use transaction.csv as input, the columns will cut the necessary fields and place into 06_reorganized_columns.tmp
	gawk -f "scripts/summary_organize.awk" < "transaction.csv" > "06_reorganized_columns.tmp"
	# 06_reorganized_columns.tmp isn't sorted, so we will use it as input, sort based on state, zip (desc_, lname, fname, and place into summary.csv
	sort -t ',' -k 2,2 -k 3rn,3 -k 4,4 -k 5,5 < "06_reorganized_columns.tmp" > "summary.csv"
	#Convert all text to upper in the summary.csv file
	tr '[:upper:]' '[:lower:]' < "summary.csv" > "summary_cap.tmp"

	#8 Transaction Report
	printf "8) Transaction Report -- complete\n"
	# Initiliaze variables that corresspond to fname lname
	# Call transaction_rpt.awk which accepts summary.csv and counts transactions per state and places into 07 tmp file
	awk -v _fname=$fname -v _lname=$lname -f "scripts/transaction_rpt.awk" <"summary_cap.tmp" > "07_unsorted_transaction.tmp"
	#07_unsorted_transaction.tmp has unsorted counts so we will sort this in descending order and place into transaction.rpt
	sort -t ' ' -r -k 2 <"07_unsorted_transaction.tmp" > "transaction.rpt"

	#11 Purchase Report
	printf "9) Purchase Report -- complete\n"
	# Call _filter_females.awk which places only the females from transaction.csv into 09_females_purchase.tmp
	gawk -f "scripts/_filter_females.awk" < "transaction.csv" > "09_females_purchase.tmp"
	# Call _filter_males.awk which places only the males from transaction.csv into 10_males_purchase.tmp
	gawk -f "scripts/_filter_males.awk" <"transaction.csv" > "10_males_purchase.tmp" 
	# Call sum_females.awk which sums the amount of purchase by state (females only file) and place into 11 tmp
	gawk -f "scripts/sum_females.awk" <"09_females_purchase.tmp" > "11_female_purchase.tmp"
	# Call sum_males.awk which sums the amount of purchase by state (males only file_ and place into 12 tmp
	gawk -f "scripts/sum_males.awk" < "10_males_purchase.tmp" > "12_male_purchase.tmp"
	# Sort the sum totals per state in 11_female_purchase_tmp in decending order and place into 13 tmp
	sort -k 3 -n -r -t ',' <"11_female_purchase.tmp" > "13_female_purchase_sort.tmp"
	# Sort the sum totals per state in 12_male_purchase_tmp in descending order and place into 14 tmp
	sort -k 3 -n -r -t ',' <"12_male_purchase.tmp" > "14_male_purchase_sort.tmp"
	# This will copy the contents of the sorted male purchase per state and female purchase per state files and combine them into 15_purchase.tmp
	cat "13_female_purchase_sort.tmp" "14_male_purchase_sort.tmp" > "15_purchase.tmp"
	# Sort 15_purchase.tmp by purchase amount in descending order and place into 16_purchase_sort.tmp
	sort -k 3 -n -r -t ',' "15_purchase.tmp" > "16_purchase_sort.tmp"
	# Initialize variables that correspond to fname lname
	# Call purchase_rpt_print.awk and place into purchase.rpt
	awk -v _fname=$fname -v _lname=$lname -f "scripts/purchase_rpt_print.awk" < "16_purchase_sort.tmp" > "purchase.rpt"

# Call rm_temps to clean out all the tmp files in directory
rm_temps

# Call rm_csv to clean out all csv
rm_csv

# Call rm_mock to remove mock
rm_MOCK
exit 0
