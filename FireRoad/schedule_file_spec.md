#  FireRoad - Schedule File Specification

The FireRoad schedule file (.sched file extension) is a JSON file with a structure as defined below. Earlier versions of FireRoad used a CSV-like format, which from now on will only be read by the FireRoad app (not written).

To see an example of read/write for .sched files, see the code in [ScheduleModel.swift](ScheduleModel.swift).

## Top-Level Objects

The top-level object is a dictionary with only one key at present:

* **selectedSubjects** - A list of selected subjects for this schedule (see below).

## Selected Subjects List

The selected subjects list contains a list of subjects that the user has put on their schedule. Each subject is represented by a dictionary containing the following keys:

* **id** - The subject ID (e.g. "6.009").
* **title** - The subject title (e.g. "Fundamentals of Programming").
* **allowedSections** - A dictionary of allowed schedule units, where the keys are the section type (e.g. "lecture", "recitation", "lab", "design"), and the values are lists of schedule unit numbers. This indicates the user-defined constraints on which schedule units can be selected. See below for information about the schedule units.
* **selectedSections** - A dictionary of selected schedule units, where the keys are the section type, and the values are single schedule unit numbers. See below for more about the schedule units.

## Schedule Units

The schedule unit is an internal model type in the FireRoad app, which represents the most granular weekly-repeating unit that a user can select in their schedule. For example, a user can select an 18.03 lecture that takes place MWF at 1pm; this would be represented by a single schedule unit.

The course database defines the schedule units for each subject, which is then internally represented as a dictionary of section types (lecture, recitation, etc.) pointing to lists of schedule units as displayed on the registrar site. Rather than specify the exact times within the document, the schedule JSON file specifies the *index* of the schedule unit that has been selected/constrained. This allows the document to be robust to changes in the exact times of each section. (If the schedule units list becomes shorter than the index specified, the FireRoad app by default reverts to the first-generated schedule option.) 

## Example

```
{
  "selectedSubjects" : [
    {
      "selectedSections" : {
        "Recitation" : 8,
        "Lecture" : 0
      },
      "title" : "Differential Equations",
      "subject_id" : "18.03",
      "allowedSections" : {
        "Recitation" : [
          0,
          3,
          4,
          7,
          8,
          9
        ]
      }
    },
    {
      "subject_id" : "6.031",
      "selectedSections" : {
        "Lecture" : 0
      },
      "title" : "Elements of Software Construction"
    },
    {
      "subject_id" : "21G.501",
      "selectedSections" : {
        "Lecture" : 1
      },
      "title" : "Japanese I"
    }
  ]
}
```
