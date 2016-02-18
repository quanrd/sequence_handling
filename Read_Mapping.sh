#!/bin/bash

#   This script generates a series of QSub submissions for read mapping
#   The Burrows-Wheeler Aligner (BWA) and the Portable Batch System (PBS)
#   are required to use this script

set -e
set -o pipefail

#   What are the dependencies for Read_Mapping?
declare -a Read_Mapping_Dependencies=(bwa)

#   A function to parse BWA settings
function ParseBWASettings() {
	local POSITIONALS='' # Create a string of positional arguments for BWA mem
	if [[ "${PAIRED}" == true ]]; then POSITIONALS="${POSITIONALS}"'-P '; fi # Add paired to the positionals
	if [[ "${INTERLEAVED}" == true ]]; then POSITIONALS="${POSITIONALS}"'-p '; fi # Add interleaved to the positionals
	if [[ "${SECONDARY}" == true ]]; then POSITIONALS='-a'; else SECONDARY=''; fi # Add secondary to the positionals
	if [[ "${APPEND}" == true ]]; then POSITIONALS="${POSITIONALS}"'-C '; fi # Add append to the positionals
	if [[ "${HARD}" == true ]]; then POSITIONALS="${POSITIONALS}"'-H '; fi # Add hard to the positionals
	if [[ "${SPLIT}" == true ]]; then POSITIONALS="${POSITIONALS}"'-M '; fi # Add split to the positionals
	if [[ "${VERBOSITY}" == 'disabled' ]]; then VERBOSITY=0; elif [[ "${VERBOSITY}" == 'errors' ]]; then VERBOSITY=1; elif [[ "${VERBOSITY}" == 'warnings' ]]; then VERBOSITY=2; elif [[ "${VERBOSITY}" == 'all' ]]; then VERBOSITY=3; elif [[ "${VERBOSITY}" == 'debug' ]]; then VERBOSITY=4; else echo "Failed to recognize verbosity level, exiting..."; exit 1; fi # Set the verbosity level
	MEM_SETTINGS=$(echo "-t ${THREADS} -k ${SEED} -w ${WIDTH} -d ${DROPOFF} -r ${RE_SEED} -A ${MATCH} -B ${MISMATCH} -O ${GAP} -E ${EXTENSION} -L ${CLIP} -U ${UNPAIRED} -T ${THRESHOLD} -v ${VERBOSITY} ${POSITIONALS}") # Assemble our settings
    echo "${MEM_SETTINGS}" # Return our settings
}

#   Export the function
export -f ParseBWASettings

#   A function to see if our referenced FASTA is indexed
function checkIndex() {
    local reference="$1" # What is our reference FASTA file?
    if ! [[ -f "${reference}" ]]; then echo "Cannot find reference genome, exiting..." >&2; exit 1; fi # Make sure it exists
    local referenceDirectory=$(dirname "${reference}") # Get the directory for the reference directory
    local referenceName=$(basename "${reference}") # Get the basename of the reference directory
    if [[ ! $(find "${referenceDirectory}" -maxdepth 1 -name "${referenceName}.amb") || ! $(find "${referenceDirectory}" -maxdepth -name "${referenceName}.ann") || ! $(find "${referenceDirectory}" -maxdepth 1 -name "${referenceName}.bwt") || ! $(find "${referenceDirectory}" -maxdepth 1 -name "${referenceName}.pac") || ! $(find "${referenceDirectory}" -maxdepth 1 -name "${referenceName}.sa") ]]; then return 1; fi # Check to make sure we have all of the index files for our reference FASTA file
}

#   Export the function
export -f checkIndex

#   A function to index the FASTA and exit
function indexReference() {
    local reference="$1" # What is our reference FASTA file?
    echo "Indexing reference, will quit upon completion..." >&2
    bwa index "${reference}" # Index our reference FASTA file
    echo "Please re-run sequence_handling to map reads" >&2
    exit 10 # Exit the script with a unique exit status
}

#   Export the function
export -f indexReference

#   A function to create our read group ID for BWA
function createReadGroupID() {
    local sample="$1" # What is our sample name?
    local project="$2" # What is the name of the project?
    local platform="$3" # What platform did we sequence on?
    local readGroupID="@RG\tID:${sample}\tLB${project}_${sample}\tPL:${platform}\tPU${sample}\tSM:${sample}" # Assemble our read group ID
    echo "${readGroupID}" # Return our read group ID
}

#   Export the function
export -f createReadGroupID

function Read_Mapping() {
    local sampleName="$1" # What is the name of our sample?
    local forwardSample="$2" # Where is the forward sample?
    local reverseSample="$3" # Where is the reverse sample?
    local project="$4" # What is the name of our project?
    local platform="$5" # What platform did we sequence on?
    local outDirectory="$6"/Read_Mapping # Where is our outdirectory?
    local reference="$7" # Where is our reference FASTA file?
    mkdir -p "${outDirectory}" # Make our outdirectory
    local memSettings=$(ParseBWASettings) # Assemble our settings for BWA mem
    local readGroupID=$(createReadGroupID "${sample}" "${project}" "${platform}") # Assemble our read group ID
    # local -a forwardSamples=($(grep -E "${forwardNaming}" "${sampleList}"))
    # local -a reverseSamples=($(grep -E "${reverseNaming}" "${sampleList}"))
    # if ! [[ "${#forwardSamples}" -ne "${reverseSamples}" ]]; then echo "Unequal numbers of forward and reverse reads, exiting..." >&2; exit 1; fi
    # exit 3
    bwa mem "${memSettings}" -R "${readGroupID}" "${reference}" "${forwardSample}" "${reverseSample}" > "${outDirectory}"/"${sample}".sam # Read map our sample
}
