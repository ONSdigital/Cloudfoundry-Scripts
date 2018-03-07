#!/usr/bin/env python

import json
import os
import pika
import sys

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

	print binding['credentials']['protocols']['amqp+ssl']['uri']

	params = pika.URLParameters(binding['credentials']['protocols']['amqp+ssl']['uri'])

	connection = pika.BlockingConnection(params)

	channel = connection.channel()

	channel.queue_declare(queue='hello')

	channel.basic_publish(exchange='',routing_key='hello',body='Hello World!')

	print(" [x] Sent 'Hello World!'")

	connection.close()
