#!/usr/bin/env ruby

# This file provides the library functions such as 'r' and 'd' that can be used from within a .tf.rb template file.
# This is done by
#   - (within the template evaluation scope in the outer script) calling load() on this file, before
#   - calling tf_template(...) (defined at the end of this file) to do the actual templating (via another load).

require 'pp'
require 'json'

def debug(*args)
	#pp(*args)
end

def _normalize_name(name)
	name.to_s.gsub(' ', '_').gsub('.', '_')  # TODO more special chars
end

class ResourceProxy
	def initialize(resources_hash, prefix='')
		@resources_hash = resources_hash
		@prefix = prefix
	end

	def method_missing(m, *args, &block)
		raise if block
		raise unless args.empty?
		return self[m]
	end

	def [](resource_type)
		return ResourceTypeProxy.new(@resources_hash, resource_type, @prefix)
	end
end

class ResourceTypeProxy
	def initialize(resources_hash, type_name, prefix='')
		@resources_hash = resources_hash
		@type_name = type_name
		@prefix = prefix
	end

	def method_missing(m, *args, &block)
		raise if block
		raise unless args.empty?
		return self[m]
	end

	def [](resource_name)
		resource_name = _normalize_name resource_name
		return ResourceReference.new(@type_name, resource_name, @prefix)
	end
end

class ResourceReference
	def initialize(type, name, prefix='')
		@type = type
		@name = _normalize_name name
		@prefix = prefix
		self
	end

	def method_missing(m, *args, &block)
		raise if block
		raise unless args.empty?
		field_name = m
		"${#{@prefix}#{@type}.#{@name}.#{field_name}}"
	end
end

class Resource
	def initialize(type, name, prefix='')
		@type = type
		@name = _normalize_name name
		@prefix = prefix
		@params = {}
		case @prefix
		when 'data.'
			$data[@type][@name] = self
		when ''
			$resources[@type][@name] = self
		else
			raise
		end
		self
	end

	def method_missing(m, *args, &block)
		debug 'missing', m, args
		param_name = m
		case args.length
		when 0
			#@params[param_name]
			"${#{@prefix}#{@type}.#{@name}.#{param_name}}"
		when 1
			prop param_name, args.first
		else
			raise "Weird argument list to #{m} in #{self.inspect}"
		end
	end

	def prop(key, value)
		@params[key] = value
		debug 'params', @params
	end

	def to_json(*args)
		@params.to_json(*args)
	end
end

$data = Hash.new {|h,k| h[k] = {} }
$resources = Hash.new {|h,k| h[k] = {} }
$extra_stuff = {}

def d(*stuff, &block)
	return ResourceProxy.new($data, 'data.') if stuff.empty?
	raise 'Data resource is lacking name' unless stuff.length==2
	resource = Resource.new(*stuff, 'data.')
	resource.instance_eval(&block) if block
	resource
end

def r(*stuff, &block)
	return ResourceProxy.new($resources) if stuff.empty?
	raise 'Resource is lacking name' unless stuff.length==2
	raise unless stuff.length==2
	resource = Resource.new(*stuff)
	resource.instance_eval(&block) if block
	resource
end

def output(name, value)
	$extra_stuff['output'] ||= {}
	$extra_stuff['output'][name] = {'value': value}
end

def tf_template(load_tf_path, json_out_stream)
	load(load_tf_path)  # TODO figure out the deal with passing a Module to wrap= ..?

	stuff = {}
	stuff[:data] = $data.sort.to_h unless $data.empty?
	stuff[:resource] = $resources.sort.to_h unless $resources.empty?  # TODO recursive sort
	stuff.merge!($extra_stuff)  # TODO sort all this too
	json_out_stream.puts JSON.pretty_generate(stuff)
end

if $PROGRAM_NAME == __FILE__
	tf_template(ARGV.first, $stdout)
end
