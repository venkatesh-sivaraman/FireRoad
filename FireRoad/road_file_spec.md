#  FireRoad - Road File Specification

The FireRoad road file (.road file extension) is a JSON file with a structure as defined below. Earlier versions of FireRoad used a CSV-like format, which from now on will only be read by the FireRoad app (not written).

To see an example of read/write for .road files, see the code in [User.swift](User.swift).

## Top-Level Objects

The top-level object is a dictionary with two keys:

* **coursesOfStudy** - A list of courses of study that the user has added (e.g. "major6", "girs"). Each course of study corresponds in name to a requirements list.
* **selectedSubjects** - A list of selected subjects (see below).

## Selected Subjects List

The selected subjects list contains a list of subjects that the user has put on their road. Each subject is represented by a dictionary containing the following keys:

* **subject_id** - The subject ID (e.g. "6.009").
* **title** - The subject title (e.g. "Fundamentals of Programming").
* **units** - The total number of units provided by this subject.
* **semester** - The semester number in which this subject is placed. The semester numbers are zero indexed, with the order as follows: *Previous Credit, Freshman Fall, Freshman IAP, Freshman Spring, ..., Senior Spring*.
* **overrideWarnings** - A boolean indicating whether the prereq/coreq and not-offered warnings should be hidden for this subject. 

### Notes

1) The information contained in each subject is intentionally redundant so that the road file can be displayed in a preliminary way without loading the entire course database.
2) The same subject ID may appear multiple times with different semester numbers, if the user selects the same subject for different semesters.
3) Subjects in the selected subjects list may be **generic courses**, which are defined in [Course.swift](Course.swift). 

## Example

```
{
  "coursesOfStudy" : [
    "girs",
    "major6-7"
  ],
  "selectedSubjects" : [
    {
      "overrideWarnings" : false,
      "semester" : 0,
      "title" : "Generic Physics I GIR",
      "subject_id" : "PHY1",
      "units" : 12
    },
    {
      "overrideWarnings" : false,
      "semester" : 1,
      "title" : "Principles of Chemical Science",
      "subject_id" : "5.112",
      "units" : 12
    },
    {
      "overrideWarnings" : false,
      "semester" : 4,
      "title" : "Fundamentals of Programming",
      "subject_id" : "6.009",
      "units" : 12
    },
    {
      "overrideWarnings" : false,
      "semester" : 4,
      "title" : "Advanced Music Performance",
      "subject_id" : "21M.480",
      "units" : 6
    },
    {
      "overrideWarnings" : false,
      "semester" : 6,
      "title" : "Advanced Music Performance",
      "subject_id" : "21M.480",
      "units" : 6
    }
  ]
}
```
