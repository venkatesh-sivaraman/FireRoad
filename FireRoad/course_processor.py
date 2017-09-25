"""Usage: python course_processor.py [input] [output dir]"""

import os, sys, math
import csv
import re

def process_list_item(list_item):
    if len(list_item) > 0:
        #mod_value = re.sub(r'permission of instructor', 'POI', line[list_item], flags=re.IGNORECASE)
        mod_value = list_item.replace("Physics I", "GIR:PHY1")
        mod_value = mod_value.replace("Physics II", "GIR:PHY2")
        mod_value = mod_value.replace("Calculus I", "GIR:CAL1")
        mod_value = mod_value.replace("Calculus II", "GIR:CAL2")
        mod_value = re.sub(r'[A-z](?=[a-z])[a-z]+', ',', list_item)
        mod_value = mod_value.replace(';', ',')
        temp_mod = mod_value
        bracketize = False
        values = []
        for comp in temp_mod.split(","):
            if "[" in comp and "]" in comp:
                values.append(comp)
                bracketize = False
            elif "[" in comp:
                bracketize = True
                values.append(comp + "]")
            elif "]" in comp:
                if bracketize:
                    values.append("[" + comp)
                else:
                    values.append(comp)
                bracketize = False
            else:
                if bracketize:
                    values.append("[" + comp + "]")
                else:
                    values.append(comp)
        return ",".join(values)
    return list_item

def term_frequencies(description):
    """
        Returns a dict where each key corresponds to a word, and the value is the frequency of that word in the description string.
        """
    comps = re.split(r'[^A-z0-9\'-]+', description.lower())
    ret = {}
    for word in comps:
        if len(word) <= 3: continue
        if word in ret:
            ret[word] += 1
        else:
            ret[word] = 1
    return ret

def doc_distance(tf1, tf2):
    """
        Computes a dot-product for the two term-frequency dictionaries provided. Returns float; higher numbers mean better correlation.
        """
    common_words = {}
    for word in tf1:
        if word in tf2:
            common_words[word] = tf1[word] * tf2[word] * math.log(len(word))
    for word in tf2:
        if word in tf1:
            common_words[word] = tf1[word] * tf2[word] * math.log(len(word))
    return sum(x for x in common_words.values())

# Todo: Implement APSP (Floyd-Warshall) for the relevance scores and produce a matrix that gives the relationship between any two courses.

def process_courses(source, dest, write_related=False):
    """
        This function takes a raw CSV file and processes it into a condensed course file, as well as a file for every course ID.

Academic Year,Effective Term Code,Subject Id,Subject Code,Subject Number,Source Subject Id,Print Subject Id,Department Code,Department Name,Subject Short Title,Subject Title,Is Variable Units,Lecture Units,Lab Units,Preparation Units,Total Units,Gir Attribute,Gir Attribute Desc,Comm Req Attribute,Comm Req Attribute Desc,Write Req Attribute,Write Req Attribute Desc,Supervisor Attribute Desc,Prerequisites,Subject Description,Joint Subjects,School Wide Electives,Meets With Subjects,Equivalent Subjects,Is Offered This Year,Is Offered Fall Term,Is Offered Iap,Is Offered Spring Term,Is Offered Summer Term,Fall Instructors,Spring Instructors,Status Change,Last Activity Date,Warehouse Load Date,Master Subject Id,Hass Attribute,Hass Attribute Desc,Term Duration,On Line Page Number

        """
    key_list = ""
    keys = {}
    reverse_keys = {}
    courses_by_dept = {}
    with open(source, "r") as file:
        reader = csv.reader(file, delimiter=',', quotechar='"')
        for line in reader:
            if "Subject Id" in line:
                key_list = line
                for i, comp in enumerate(key_list):
                    keys[comp] = i
                    reverse_keys[i] = comp
            else:
                id = line[keys["Subject Id"]]
                dept = id[:id.find(".")]
                '''lists = [keys["Prerequisites"], keys["Joint Subjects"], keys["Meets With Subjects"], keys["Equivalent Subjects"]]
                for list_item in lists:
                    if list_item < 0: continue
                    if len(line[list_item]) > 0:
                        line[list_item] = "{}#,#{}".format(line[list_item], process_list_item(line[list_item]))'''

                # Use to determine possible values for various attributes
                #if len(line[keys["Write Req Attribute"]]) > 0:
                #    print("HASS: ", line[keys["Write Req Attribute"]], "for course ", id)
                if dept in courses_by_dept:
                    if id not in courses_by_dept[dept]:# or int(line[keys["Academic Year"]]) > int(courses_by_dept[dept][id][keys["Academic Year"]]):
                        courses_by_dept[dept][id] = line
                else:
                    courses_by_dept[dept] = {id : line}
    # Write the contents to file
    if not os.path.exists(dest):
        os.mkdir(dest)
    #for dept, courses in courses_by_dept.items():
    #    for id in courses:
    #        courses[id] = [(x if x.replace(' ', '').replace(',','') == x else '"' + x + '"') for x in courses[id]]


    with open(os.path.join(dest, "auto_condensed.txt"), "w") as file:
        restricted_keys = [
            "Subject Id", "Subject Title", "Total Units", "Not Offered Year", "Is Offered Fall Term", "Is Offered Iap", "Is Offered Spring Term", "Is Offered Summer Term"
                           ]
        print("Writing condensed course file...")
        file.write(','.join(restricted_keys) + '\n')
        for dept, courses in courses_by_dept.items():
            for id, course in courses.items():
                print(course)
                file.write(','.join([x for i, x in enumerate(course) if reverse_keys[i] in restricted_keys]) + '\n')

    print("Writing department summaries...")
    for dept in courses_by_dept:
        with open(os.path.join(dest, dept + ".txt"), "w") as file:
            file.write(','.join(key_list) + '\n')
            for id, course in courses_by_dept[dept].items():
                file.write(','.join(course) + '\n')
    
    with open(os.path.join(dest, "related.txt"), "w") as file:
        print("Writing related courses...")
        
        # Determine related courses
        tf_lists = {}
        k = 10
        for dept, courses in courses_by_dept.items():
            for id, course in courses.items():
                tf_lists[id] = term_frequencies(course[keys["Subject Description"]])

        # First determine which departments are closely related to each other
        dept_lists = {}
        for dept, courses in courses_by_dept.items():
            for id, course in courses.items():
                if dept not in dept_lists: dept_lists[dept] = {}
                for term, freq in tf_lists[id].items():
                    if term in dept_lists[dept]:
                        dept_lists[dept][term] += freq
                    else:
                        dept_lists[dept][term] = freq
        dept_similarities = {}
        for dept1 in dept_lists:
            for dept2 in dept_lists:
                if len(dept_lists[dept1]) == 0 or len(dept_lists[dept2]) == 0:
                    dept_similarities[(dept1, dept2)] = 0.00001
                    dept_similarities[(dept2, dept1)] = 0.00001
                    continue
                sim = max(doc_distance(dept_lists[dept1], dept_lists[dept2]) ** 2 / (doc_distance(dept_lists[dept1], dept_lists[dept1]) * doc_distance(dept_lists[dept2], dept_lists[dept2])), 0.00001)
                #sim = math.log(sim) / math.log(2.0)
                dept_similarities[(dept1, dept2)] = sim
                dept_similarities[(dept2, dept1)] = sim

        progress = 0
        progress_stepwise = 0
        for dept, courses in courses_by_dept.items():
            for id, course in courses.items():
                ranks = [("", 0) for i in range(k)]
                for other_id, tf in tf_lists.items():
                    if other_id == id or other_id in course[keys["Equivalent Subjects"]] or other_id in course[keys["Joint Subjects"]] or other_id in course[keys["Meets With Subjects"]]: continue
                    dist = doc_distance(tf_lists[id], tf) * dept_similarities[(dept, other_id[:other_id.find(".")])]
                    for i in range(k):
                        if dist >= ranks[i][1]:
                            comp_dept = ranks[i][0][:ranks[i][0].find(".")]
                            if comp_dept in courses_by_dept:
                                comp_course = courses_by_dept[comp_dept][ranks[i][0]]
                                if (other_id == ranks[i][0] or other_id in comp_course[keys["Equivalent Subjects"]] or other_id in comp_course[keys["Joint Subjects"]] or other_id in comp_course[keys["Meets With Subjects"]]) and comp_dept != dept: break
                            ranks.insert(i, (other_id, dist))
                            del ranks[-1]
                            break
                ranks = [[x, "{:.3f}".format(y)] for x, y in ranks if y > 0]
                file.write(','.join([id] + [item for sublist in ranks for item in sublist]) + '\n')
            progress += 1
            if round(progress / len(courses_by_dept) * 10.0) == progress_stepwise + 1:
                progress_stepwise += 1
                print("{}% complete...".format(progress_stepwise * 10))

if __name__ == '__main__':
    args = sys.argv
    if len(args) > 3:
        if args[3] == "-r":
            process_courses(args[1], args[2], True)
        else:
            process_courses(args[1], args[2], False)
    else:
        process_courses(args[1], args[2])
