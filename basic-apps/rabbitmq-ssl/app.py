#!/usr/bin/env python

import json
import os
import ssl
import sys

import pika

service = 'rabbitmq'

# Do we have the correct env set?
if not(os.getenv('VCAP_SERVICES')):
	sys.stderr.write('No JSON provided, set VCAP_SERVICES\n')
	sys.exit(1)

# Can we load it?
try:
	services = json.loads(os.getenv('VCAP_SERVICES'))
except:
	sys.stderr.write('Unable to load JSON from $VCAP_SERVICES\n')
	sys.exit(1)

# Does it look semi-valid?
if not(service in services.keys()):
	sys.stderr.write('%s does not exist in JSON\n' % service)
	sys.exit(1)

# Does it look more valid?
if type(services[service]) != list:
	sys.stderr.write('JSON[%s] does not contain any bindings\n' % service)
	sys.exit(1)

for binding in services[service]:
	if not('credentials' in binding.keys()) or not('name' in binding.keys()):
		continue

		#host=binding['credentials']['protocols']['amqp+ssl']['host'],
	params = pika.ConnectionParameters(
		host='10.0.51.45',
		port=binding['credentials']['protocols']['amqp+ssl']['port'],
		credentials=pika.PlainCredentials(binding['credentials']['protocols']['amqp+ssl']['username'],binding['credentials']['protocols']['amqp+ssl']['password']),
		ssl=True,
		ssl_options=dict(ssl_version=ssl.PROTOCOL_TLSv1_2)
	)

	try:
		connection = pika.BlockingConnection(params)
	except BaseException as e:
		sys.stderr.write(str(e), e.__class__.__name)

	try:
		sys.stderr.write('connection', connection)
	except NameError as e:
		sys.stderr.write(str(e), e.__class__.__name)

	channel = connection.channel()

	channel.queue_declare(queue='hello')

	channel.basic_publish(exchange='',routing_key='hello',body='Hello World!')

	print(" [x] Sent 'Hello World!'")

	connection.close()
