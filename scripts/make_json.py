import json
import sys
import os

from collections import defaultdict

BASE_DIR = '/root/'
headers = {
    'Content-Type': 'application/json'
}
url = 'http://scruffy.soe.ucsc.edu:5000/'

result = defaultdict(lambda: result)

def find_cpu_test_csv_filenames(path_to_dir):
    result = list()
    filenames = os.listdir(path_to_dir)
    for filename in filenames:
        if filename.startswith('npb') and filename.endswith('.csv'):
            result.append(filename)
    return result

if __name__ == "__main__":
    
    machine_id = sys.argv[1]
    nsockets = int(sys.argv[2])

    # CPU benchmarks
    # Aggregate the cpu tests
    # for filename in find_cpu_test_csv_filenames(BASE_DIR):
    #     f = open(os.path.join(BASE_DIR, filename), 'w+')
    #     data = f.read()
    #     f.close()

    #     rows = data.split("\n")[0]
    #     cols = data.split("\n")[1]

    #     keys = rows.split(",")
    #     values = cols.split(",")

    #     info = dict()
    #     for i, j in zip(keys, values):
    #         info[i.strip()] = j.strip()

    #     result['cpu_st'][info['testname']] = info
    
    membench_info = dict()
    f = open(os.path.join(BASE_DIR, 'membench_info.csv'))
    data = f.read()
    f.close()

    keys = data.split("\n")[0].split(",")
    values = data.split("\n")[1].split(",")

    for i, j in zip(keys, values):
        membench_info[i] = j

    membench_benchmark = dict()
    for sno in range(0, nsockets):
        filename="membench_out_socket{}_dvfs.csv".format(sno)
        f = open(os.path.join(BASE_DIR, filename))
        data = f.read()
        f.close()
        membench_benchmarks[sno] = dict()
        
        keys = data.split("\n")[0].split(",")
        values = data.split("\n")[1].split(",")

        for i, j in zip(keys, values):
            membench_benchmarks[sno][i] = j

    result['memory']['membench']['membench_info'] = membench_info
    result['memory']['membench']['membench_benchmark'] = membench_benchmark
    print(result)
