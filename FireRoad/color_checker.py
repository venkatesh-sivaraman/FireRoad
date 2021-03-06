'''Purpose is to check that course colors don't overlap or match.'''
colors = {
    "1": (0.0, 0), "2": (20.0, 0),
    "3": (225.0, 0), "4": (128.0, 1),
    "5": (162.0, 0), "6": (219.0, 0),
    "7": (218.0, 2), "8": (267.0, 2),
    "9": (264.0, 0), "10": (0.0, 2),
    "11": (342.0, 1), "12": (125.0, 0),
    "14": (30.0, 0), "15": (3.0, 1),
    "16": (197.0, 0), "17": (315.0, 0),
    "18": (236.0, 1), "20": (135.0, 2),
    "21": (130.0, 2), "21A": (138.0, 2),
    "21W": (146.0, 2), "CMS": (154.0, 2),
    "21G": (162.0, 2), "21H": (170.0, 2),
    "21L": (178.0, 2), "21M": (186.0, 2),
    "WGS": (194.0, 2), "22": (0.0, 1),
    "24": (260.0, 1), "CC": (115.0, 0),
    "CSB": (197.0, 2), "EC": (100.0, 1),
    "EM": (225.0, 1), "ES": (242.0, 1),
    "HST": (218.0, 1), "IDS": (150.0, 1),
    "MAS": (122.0, 2), "SCM": (138.0, 1),
    "STS": (276.0, 2), "SWE": (13.0, 2),
    "SP": (240.0, 0)
}

sorted_colors = sorted(map(lambda k: (colors[k], k), colors.keys()), key=lambda x: x[0][1] * 400 + x[0][0])
for (color, key) in sorted_colors:
    print(str(color[1]) + "\t" + str(color[0]) + "\t({})".format(key))
