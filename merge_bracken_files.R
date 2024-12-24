# Load required libraries
library(readr)  # For reading and writing tabular data
library(dplyr)  # For data manipulation

# Define the base directory containing Bracken files
BASE_DIR <- "/home/user/project/results/bracken/"

# Example folder structure for input files:
# BASE_DIR/
# ├── barcode01_bracken
# ├── barcode02_bracken
# ├── barcode03_bracken
# ├── barcode04_bracken
# ├── barcode05_bracken
# ├── barcode06_bracken
# └── ...



# List all files in the directory with the extension 'bracken'
bracken_paths <- list.files(
  path = file.path(BASE_DIR),   # Path to the directory
  pattern = "bracken$",        # Regex pattern to match files with '.bracken' extension
  full.names = TRUE,           # Include the full path in the output
  recursive = TRUE             # Search subdirectories
)
bracken_paths  # Print the list of file paths

# Create an empty list to store Bracken data
bracken_data <- list()

# Loop through each file path to read and process Bracken data
for (i in seq_along(bracken_paths)) {
  # Extract the file name from the file path
  file_name <- basename(bracken_paths[i])
  
  # Extract the barcode name using a regular expression
  barcode_name <- sub("^(barcode[0-9]+).*", "\\1", file_name)
  
  # Read the Bracken file and process the data
  bracken <- read_delim(bracken_paths[i], delim = "\t", show_col_types = FALSE) %>%
    select(name, new_est_reads) %>%           # Select columns of interest
    rename(!!barcode_name := new_est_reads) %>%  # Rename 'new_est_reads' column using the barcode name
    rename(specie = name) %>%                 # Rename 'name' column to 'specie'
    arrange(specie)                           # Sort rows by species
     
  # Store the processed data in the list
  bracken_data[[i]] <- bracken
}

# Combine all processed data frames into a single data frame
bracken_combined <- Reduce(
  function(x, y) full_join(x, y, by = "specie"),  # Merge data frames on the 'specie' column
  bracken_data
)

# Replace any NA (missing) values with 0
bracken_combined[is.na(bracken_combined)] <- 0

file_name  # Print the last processed file name (optional)

# Convert the combined data to a data frame
join_bracken <- as.data.frame(bracken_combined)

# Check the structure of the combined data
str(join_bracken)

# Print the combined data frame
join_bracken

# Save the combined data frame to a TSV file
write_tsv(join_bracken, "Pluspf_bracken.tsv")
