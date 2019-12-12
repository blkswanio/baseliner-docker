import json
import sys
import os

from collections import defaultdict


BASE_DIR = '/root/'
headers = {
    'Content-Type': 'application/json'
}
url = 'http://scruffy.soe.ucsc.edu:5000/api/v1/save-benchmark'


def ddict():
    return defaultdict(ddict)


def ddict2dict(d):
    for k, v in d.items():
        if isinstance(v, dict):
            d[k] = ddict2dict(v)
    return dict(d)


def find_npb_cpu_st_tests():
    result = list()
    filenames = os.listdir('/root/')
    for filename in filenames:
        if filename.startswith('npb') and filename.endswith('ST.csv'):
            result.append(filename)
    return result


result = ddict()


if __name__ == "__main__":
    
    machine_id = sys.argv[1]
    nsockets = int(sys.argv[2])

    cpu_benchmark = dict()
    cpu_benchmark['st'] = dict()
    npb_cpu_st_results = find_npb_cpu_st_tests()
    for sno in range(0, nsockets):
        socketid = "socket{}".format(sno)
        cpu_benchmark['st'][socketid] = list()
        for res in npb_cpu_st_results:
            if socketid in res:
                f = open(os.path.join(BASE_DIR, res))
                data = f.read()
                f.close()

                keys = data.split("\n")[0].split(",")
                values = data.split("\n")[1].split(",")
                cpu_benchmark['st'][socketid].append(dict(zip(keys, values)))
    
    result['cpu'] = cpu_benchmark

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
        membench_benchmark["socket_{}".format(sno)] = dict()
        
        keys = data.split("\n")[0].split(",")
        values = data.split("\n")[1].split(",")

        for i, j in zip(keys, values):
            membench_benchmark["socket_{}".format(sno)][i] = j

    result['memory']['membench']['membench_info'] = membench_info
    result['memory']['membench']['membench_benchmark'] = membench_benchmark

    stream_info = dict()
    f = open(os.path.join(BASE_DIR, 'stream_info.csv'))
    data = f.read()
    f.close()

    keys = data.split("\n")[0].split(",")
    values = data.split("\n")[1].split(",")

    for i, j in zip(keys, values):
        stream_info[i] = j

    stream_benchmark = dict()
    for sno in range(0, nsockets):
        filename="stream_out_socket{}_dvfs.csv".format(sno)
        f = open(os.path.join(BASE_DIR, filename))
        data = f.read()
        f.close()
        stream_benchmark["socket_{}".format(sno)] = dict()
        
        keys = data.split("\n")[0].split(",")
        values = data.split("\n")[1].split(",")

        for i, j in zip(keys, values):
            stream_benchmark["socket_{}".format(sno)][i] = j

    result['memory']['stream']['stream_info'] = stream_info
    result['memory']['stream']['stream_benchmark'] = stream_benchmark

    print(json.dumps(ddict2dict(result)))
