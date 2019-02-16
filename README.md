#  FireRoad : MIT course planner

FireRoad is an iOS application that aims to combine two pillars of the MIT web-app ecosystem: CourseRoad, for planning four-year tracks, and Firehose, for planning semester schedules.

## Design

FireRoad has been designed and developed with two primary objectives:

1. **UI Aesthetic**. For almost any course-related task at MIT, it's likely that a piece of software already exists to accomplish it – but often, these tools are developed from a functional or incremental standpoint. FireRoad was imagined as a response to all of these tools that would put the overall user experience first.
2. **Future-flexible**. It is a sad truth that many (beloved) tools at MIT are relatively quick to reach senescence after their creator leaves MIT. FireRoad will undoubtedly reach a similar state, but in an effort to reduce this decay rate, several measures have been taken to make it easy to update and maintain the application. These are detailed below.

With this in mind, FireRoad is published under an MIT license and allows you to extend and create new functionalities if you so desire. Moreover, I encourage you to contact me with code modifications if you'd like them to be included in the production release!

## Building and Running

Upon cloning the repo to your local machine, you should be able to build and run FireRoad by opening the Xcode project in **Xcode 10.1**.

Below, I have provided a rudimentary description of how FireRoad's internals are structured.

## Server

FireRoad depends on a server to provide subject ratings and recommendations, as well as to serve subject listings and requirements lists. As of 2/16/19, this server is located at `fireroad.mit.edu`. The server handles login, document cloud sync, and recommendations, and also serves a static directory at `/catalogs/` that contains the subject listings and requirements files themselves. The Django server code lives in [a separate GitHub repo](https://github.com/venkatesh-sivaraman/fireroad-server/tree/develop). If you contact me, I can provide additional scripts that may help perform automatic updates.

## Subject Listing

The MIT subject listing is scraped from the [registrar's website](http://student.mit.edu/catalog/index.cgi) using the `CourseCatalogScrubber`. This is a Swift command-line tool that automatically reads each department's webpage(s) and writes the subject attributes to CSV. This CSV file is further processed using NLP to extract keywords, related subjects, and features for the recommendation engine. The parsing pipeline is designed to be modular, so if one component changes, it should be relatively uncomplicated to modify that part while maintaining the formats necessary to present the subject listings to the user.

## Requirements Lists

The maintenance of the requirements lists (in the Requirements tab of FireRoad) will likely require the most frequent work - therefore, its format was carefully considered in order to make updating as straightforward as possible.

Requirement edit requests are received on the server from the [Requirements Editor](https://fireroad.mit.edu/requirements). The way I handle changing requirements lists is by modifying my local copy of the requirements, then `scp`ing it to the repo, then running the same delta computation as in "Subject Listing" to transfer the updates into the served directory.

## File Type Specifications

* Requirements list files are written in the format specified at [`FireRoad/course_requirements_spec.md`](FireRoad/course_requirements_spec.md).
* Road files are specified by [`FireRoad/road_file_spec.md`](FireRoad/road_file_spec.md).
* Schedule files are specified by [`FireRoad/schedule_file_spec.md`](FireRoad/schedule_file_spec.md). 
