import json
import sys
from os import listdir

result = {
    "NBP-TESTS-ST": {}
}

def find_csv_filenames(path_to_dir, suffix=".csv"):
    filenames = listdir(path_to_dir)
    return [ filename for filename in filenames if filename.endswith( suffix ) ]

if __name__ == "__main__":
    for file in find_csv_filenames('/root/'):
        f = open('/root/{file}', 'w+')
        data = f.read()
        f.close()

        rows = data.split("\n")[0]
        cols = data.split("\n")[1]

        keys = rows.split(",")
        values = cols.split(",")

        info = dict()
        for i, j in zip(keys, values):
            info[i.strip()] = j.strip()

        result['NBP-TESTS-ST'][info['testname']] = info

    json_str = json.dumps(result)
    print(json_str)
