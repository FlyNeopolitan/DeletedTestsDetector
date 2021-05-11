#!/bin/bash 

############ initialize variables ##############

dataResource=https://github.com/TestingResearchIllinois/idoft
data_file=pr-data.csv
result_name=result


############ helper methods part ##############

# check all tests for data which satisfies a certain condition
# parameters in order: file_name. 
function processDataFile_for_condition() {
  File=$1
  while IFS=, read -r URL SHADetected Module FullyTestName Category Status PRLink Notes
  do
    if filterCondition $Status ; then
      check_data $URL $Module $FullyTestName $SHADetected
    fi
  done < $File
}


# function for filtering datas
# return true(0) if we want to choose current data
# Currently the method return true if the data's status is empty
# current paramters: status
function filterCondition() {
  Status=$1
  [[ "$Status" == "" ]]
}


# check according test's information for target's data
# paramters in order: project URL, Module Path, Fully-Qualified Test Name
function check_data() {
  URL=$1
  module=$2
  fullyTestName=$3
  sha=$4
  testMethod=$(methodName_from_fullyName $fullyTestName)
  testClass=$(testClass_from_fullyName $fullyTestName)
  log_test_info $URL $module $testClass $testMethod $sha
}


# log test information
# paramters in order: URL, Module, testClass, testMethod
# Currently we only check latest 10 commites for efficiency
function log_test_info() {
  URL=$1
  module=$2
  TestClass=$3
  testMethod=$4
  sha=$5
  resultFile=../$result_name
  get_project $URL

  change_commit_to $sha
  test_info_for_commit $testMethod $TestClass $module $sha | tee -a $resultFile
  back
}


# get testClass's name from data
# for example, convert com.intuit.karate.JsonUtilsTest.testPojoConversion to JsonUtilsTest
# parameter: data
function testClass_from_fullyName() {
  data=$1
  split=(${data//./ })
  length=${#split[*]}
  echo ${split[$length - 2]}
}


# get method's name from data
# for example, convert com.intuit.karate.JsonUtilsTest.testPojoConversion[nothing] to testPojoConversion
# parameter: data
function methodName_from_fullyName() {
  data=$1
  split=(${data//./ })
  length=${#split[*]}
  target=${split[$length - 1]}
  #removeBracket
  removeBracket=(${target//[/ })
  echo ${removeBracket[0]}
}


# get project from github
# paramters in order: URL
function get_project() {
  URL=$1
  slug=$(slug_from_url $URL)
  if [ ! -d "$slug" ]; then
    git clone $URL $slug
  fi
  cd $slug
}


#get according slug based on URL
#paramters: URL
function slug_from_url() {
  URL=$1
  prefix=https:github.com
  #remove '/'
  slug=${URL///}
  #remove 'https:github.com'
  slug=${slug#"$prefix"}
  echo "$slug"
}


# get the information of target test in current commit
# paramters in order: test name, test_file, module, sha
function test_info_for_commit() {
  testMethod=$1
  TestClass=$2
  module=$3
  sha=$4
  if ! test_exists $TestClass $testMethod $module java && ! test_exists $TestClass $testMethod $module scala && ! test_exists $TestClass $testMethod $module groovy; then
    echo Test $testClass $testMethod does NOT exist in $sha
  #  else
  #   echo Test $testClass $testMethod DOES exist in the latest commit
  fi
}


# the method to check if a test exists
# parameters in order: testClass, testMethod, module, file format(java, scala, etc)
# Currently this method checks if the name of testMethod exsits in testClass file in the module directory
function test_exists() { 
  testClass=$1
  testMethod=$2
  module=$3
  format=$4
  string_exists $testMethod $testClass.$format $module && return
  #inner class issue
  innerClass_exists $testClass $testMethod $module $format && return
  #super class issue
  superClass_exists $module $testClass $testMethod $format false
}


# the method to check if a test exists as an inner class
# parameters in order: testClass, testMethod, module, file format, flag
function innerClass_exists() {
  testClass=$1
  testMethod=$2
  module=$3
  format=$4
  
  if [[ $testClass =~ "$" ]]; then
    outClassName=$(outClass testClass)
    string_exists $testMethod $outClassName.$format $module
    return
  fi
  false
}

# the method to deal with super class issue
# paramters in order: module, testClass, testMethod, format, checking flag
function superClass_exists() {
  module=$1
  testClass=$2
  testMethod=$3
  format=$4
  shouldCheck=$5
  if [ -d "$module" ]; then
    for file in $(find -name $testClass.$format); do
      if $shouldCheck; then
        if grep -q $testMethod $file ; then
          return 0
        fi
      fi
      # get superclass name
      superClass=$(getSuperClass $file $testClass)
      if [ ! -z "$superClass" -a "$superClass" != " " ]; then
        superClass_exists $module $superClass $testMethod $format true && return
      fi
    done
  fi
  false
}

# the method to get the super class 
# paramters in order: file, testClass
# for example, convert 'class barClass<K, V> extends foolClass<K, V> { ' to 'foolClass'
function getSuperClass() {
  file=$1
  testClass=$2
  #for example, convert 'class barClass<K, V> extends foolClass<K, V> { ' to 'foolClass<K, V>'
  s=$(<$file grep -A 3 "class $testClass.*" | sed -n 's/^.*extends \(.*\).*$/\1/p' $file) 
  #remove '<,>' part
  split=(${s//</ })
  s=${split[0]}
  #remove '{' part
  split=(${s//{/ })
  s=${split[0]}
  echo $s
}

# the method to get outClass
# paramter: testClass
# example: input AbstractTestMap$TestMapEntrySet output AbstractTestMap
function outClass() {
  testClass=$1
  split=(${testClass//$/ })
  length=${#split[*]}
  echo ${split[$length - 2]}
}

# Given a file name, the method checks if a string exsits in the file in the directory
# parameters in order: string_name, file_name, directory_name
function string_exists() {
  target=$1
  fileName=$2
  directory=$3
  
  if [ -d "$directory" ]; then
    for file_ in $(find $directory -name $fileName); do
      grep -q "$target" $file_ && return
    done
  fi
  false
}


# back to latest commit and result's directory
function back() {
  cd ..
}

# get data sources
# parameters: URL
function get_data() {
  URL=$1
  if [ ! -d "data" ]; then
    git clone $URL data
  fi
}

# the method to change commit to target SHA
# paramters: SHA
function change_commit_to() {
  sha=$1
  currentSHA=$(git log -1 --pretty=%H)
  if [[ ! $currentSHA == $sha ]]; then
    git checkout $sha
  fi
}

############ executing part ##############

# currently we check tests whose status is empty for the latest commits
get_data $dataResource
processDataFile_for_condition data/$data_file

