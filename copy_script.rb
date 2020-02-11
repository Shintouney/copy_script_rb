#!/usr/bin/ruby -w
require 'json'

ENVIRONMENTS	 = ["preprod", "prod"]
PATH_TSC 	 = "/home/tsc/"
PATH_KUBE_CONFIG = "#{PATH_TSC}.kube/"
PATH_SUPER_TSC   = "#{PATH_TSC}super_tsc/"
KUBECTL_CMD	 = "kubectl -n"
KUBE_JQ_ITEMS    = "| jq \'.items[] | select(.metadata.labels.job == null) | select(.status.phase != \"Completed\") \
	| [{\"pod\": {\"name\": .metadata.name, \"phase\": .status.phase, \"starting_time\": .status.startTime}, \
	\"nodes\": .status.containerStatuses | values | map({\"name\": .name, \"ready\": .ready, \"state\": .state })}]'"

# ADD GEM AND USE IT LOCALY (no need to have root permision)
# Because can't install gem to the main directory (only root have the power)
# puts, exec, system can execute shell cmd, system do not line return when clear is called

def check_arguments
  if ARGV.size == 0
    system 'clear'
    display_default_message
    display_usage
    exit(0)
  elsif ARGV.size != 3
     system 'clear'
     puts "Error: Wrong numbers of arguments\n"
     display_usage
     exit(-1)
  end
end

def display_default_message
  puts "Copy file from rails app which are located in public path\n"
  puts "Because containers are supposed to be immutable, the file will be removed after being copied"
  puts "The copied file will be saved in copied_files directory"
  puts "\n"
end

def display_usage
  puts "Usage:	 ./copy_from_pod.rb <env> <namespace> filename"
  puts "Example: ./copy_from_pod.rb preprod cineday user_data.csv"
  puts "Available environments : preprod | prod"
end

def check_environments
  if ENVIRONMENTS.include?(ARGV[0])
    puts "env selected #{ARGV[0]}\n"
    puts "namespace selected #{ARGV[1]}\n"
  else
    puts "Error \n"
    puts "Only theses environments are available: #{ENVIRONMENTS.join(' ').to_s}\n" 
    exit(-1)
  end
end

def export_kube_config
  "export KUBECONFIG=#{PATH_KUBE_CONFIG}kube-config_user-tsc_#{ARGV[0]}.yaml"
end

def display_unknown_podname name: 
  system 'clear'
  puts "Error: Unknown podname #{name}"
  exit(-1)
end

def get_and_save_pid
  "echo $$ > #{PATH_SUPER_TSC}tmp/current.pid"
end

def get_and_remove_pid
  output = `cat #{PATH_SUPER_TSC}tmp/current.pid`
  `rm #{PATH_SUPER_TSC}tmp/current.pid`
  output.delete!("\n")
end

def get_pods_by_namespace
  cmd     = "#{export_kube_config} ; #{KUBECTL_CMD} #{ARGV[1]} get pods --show-labels=true --sort-by=.metadata.name | grep --invert-match -E \"Completed|,job=\" ; #{get_and_save_pid}"
  output  = `#{cmd}`
  cmd     = "#{export_kube_config} ; #{KUBECTL_CMD} #{ARGV[1]} get pods --no-headers=true --sort-by=.metadata.name -o json #{KUBE_JQ_ITEMS}"
  output  = `#{cmd}`
  display_unknown_podname(name: ARGV[1]) if output.empty?
  JSON.parse(output).first["pod"]["name"]
end

def copy_file_to_destination name:
  system 'clear'
  folder_name = "#{ARGV[0]}_#{ARGV[1]}"
  puts folder_name
  cmd = "mkdir #{PATH_SUPER_TSC}#{folder_name} > /dev/null 2>&1"
  `#{cmd}`
  cmd = "#{export_kube_config} ; #{KUBECTL_CMD} #{ARGV[1]} cp #{name}:public/#{ARGV[2]} #{PATH_SUPER_TSC}#{folder_name}/."
  `#{cmd}`
  puts "the file #{ARGV[2]} was successfully copied in #{PATH_SUPER_TSC}#{folder_name}/"
end

# Checks args
check_arguments
check_environments

# Runs most of kubectl commands (export env, connect to pods, get the namespace and run the copy)
copy_file_to_destination name: get_pods_by_namespace
