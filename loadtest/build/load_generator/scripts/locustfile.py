import logging
import gevent
import pprint
import os
import time
from gevent.queue import Queue
from locust import HttpLocust, TaskSet, task, events
from influxdb.influxdb08 import InfluxDBClient

host = os.getenv('INFLUXDB_HOST', 'influxdb')
port = int(os.getenv('INFLUXDB_PORT', '8086'))
user = os.getenv('INFLUXDB_USER', 'root')
pw = os.getenv('INFLUXDB_PASSWORD', 'root')
name = os.getenv('INFLUXDB_NAME', 'k8s')

influx_client = InfluxDBClient (host, port, user, pw, name)
influx_queue = Queue()

def influx_worker():
  """The worker pops each item off the queue and sends it to influxdb."""
  while True:
    data = influx_queue.get()
    name = data['name']
    receipt_time = data.pop('received_time')

    write_to_influx(data)

    data['time'] = receipt_time
    data['name'] = name + ".received"
    write_to_influx(data)

    data['time'] = int(time.time())
    data['name'] = name + ".written"
    write_to_influx(data)

def write_to_influx(data):
  data = dict(data)
  name = data.pop('name')
  columns = sorted(data.keys())
  points = map(data.get, columns)
  json_body = [{ "name": name, "columns": columns, "points": [points] }]
  influx_client.write_points (json_body)
  # logging.debug('Wrote %s', pprint.pformat(json_body, 2))

def get_requests_per_second(stat, client_id):
  request = stat['method'] + stat['name'].replace('/', '-')
  request_key = "locust.{0}.reqs_per_sec.{1}".format(request, client_id)

  for epoch_time, count in stat['num_reqs_per_sec'].items():
    now = int(time.time())
    influx_queue.put({
      'name': 'trogdor_rps',
      'value': count,
      'time': epoch_time, 
      'request_key': request_key,
      'received_time': now
    })

def get_response_time(stat, client_id):
  request = stat['method'] + stat['name'].replace('/', '-')

  request_key = "locust.{0}.response_time.{1}".format(request, client_id)
  epoch_time = int(stat['start_time'])

  # flatten a dictionary of {time: count} to [time, time, time, ...]
  response_times = []
  for t, count in stat['response_times'].iteritems():
    for _ in xrange(count):
      response_times.append(t)

  for response_time in response_times:
    now = int(time.time())
    influx_queue.put({
      'name': 'trogdor_rts',
      'value': response_time,
      'time': epoch_time,
      'request_key': request_key,
      'received_time': now
    })

def slave_report_log (client_id, data, ** kw):
  for stat in data['stats']:
    get_response_time(stat, client_id)
    get_requests_per_second(stat, client_id)

class JsonSerialization(TaskSet):
  @task(1)
  def json(self):
    with self.client.get("/json", catch_response=True) as response:
      logging.debug('Response headers:')
      logging.debug(pprint.pformat(response.headers, 2))
      logging.debug('Response content:')
      logging.debug(response.content)    

class WebsiteUser(HttpLocust):
  task_set = JsonSerialization

gevent.spawn(influx_worker)
events.slave_report += slave_report_log
