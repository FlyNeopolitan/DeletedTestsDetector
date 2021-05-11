# DeletedTestsDetector

Useds to detect deleted tests (only consider those with empty status, i.e. Status == "") from dataset.  

- DatasetDifference.csv: results of deleted tests when using sha from dataset
- DeletedTests.csv: results of deleted tests with latest sha
- check_correctness.sh: the script to print out results of DatasetDifference.csv
- task.sh: the script to print out results of DeletedTests.csv
