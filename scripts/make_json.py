import json
import sys
import os
import requests

BASE_DIR = '/root/'
headers = {
    'Content-Type': 'application/json'
}
url = 'http://scruffy.soe.ucsc.edu:5000/'

result = {
    "cpu_st": {},
    "cpu_mt": {},
    "disk": {},
    "network": {}
}

def find_cpu_test_csv_filenames(path_to_dir):
    result = list()
    filenames = os.listdir(path_to_dir)
    for filename in filenames:
        if filename.startswith('npb') and filename.endswith('.csv'):
            result.append(filename)
    return result

if __name__ == "__main__":
    # CPU benchmarks
    # Aggregate the cpu tests
    for filename in find_cpu_test_csv_filenames(BASE_DIR):
        f = open(os.path.join(BASE_DIR, filename), 'w+')
        data = f.read()
        f.close()

        rows = data.split("\n")[0]
        cols = data.split("\n")[1]

        keys = rows.split(",")
        values = cols.split(",")

        info = dict()
        for i, j in zip(keys, values):
            info[i.strip()] = j.strip()

        result['cpu_st'][info['testname']] = info



        # send data to server
        result['machine_id'] = sys.argv[1]
        r = requests.post(url, data=json.dumps(result), headers=headers)
        print(r.status_code)
