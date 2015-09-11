# encoding: utf-8
require 'kubeclient'

class EventProcessor
  def initialize
    
    ssl_options = { verify_ssl: OpenSSL::SSL::VERIFY_NONE }
    @client = Kubeclient::Client.new ENV.fetch('KUBERNETES_API_URL', 'https://kubernetes:443/api/'), ENV.fetch('KUBERNETES_API_VER', 'v1'), ssl_options: ssl_options
    
    @colors = {}
    @golden_ratio_conjugate = 0.618033988749895
    @h = 10
  end

  # HSV values in [0..1[
  # returns [r, g, b] values from 0 to 255
  def hsv_to_rgb(h, s, v)
    h_i = (h*6).to_i
    f = h*6 - h_i
    p = v * (1 - s)
    q = v * (1 - f*s)
    t = v * (1 - (1 - f) * s)
    r, g, b = v, t, p if h_i==0
    r, g, b = q, v, p if h_i==1
    r, g, b = p, v, t if h_i==2
    r, g, b = p, q, v if h_i==3
    r, g, b = t, p, v if h_i==4
    r, g, b = v, p, q if h_i==5
    [(r*256).to_i, (g*256).to_i, (b*256).to_i]
  end

  def get_random_color(host)
    @h += @golden_ratio_conjugate
    @h %= 1
    color = hsv_to_rgb(@h, host ? 0.1 : 0.99, 0.99)

    color_as_hex = "#"
    color.each do |component|
      hex = component.to_s(16)
      if component < 16
        color_as_hex << "0#{hex}"
      else
        color_as_hex << hex
      end
    end

    color_as_hex
  end

  def get_color(host = false)
    color = get_random_color(host)

    while @colors.select{|key, val| val == color }.length != 0 do
      color = get_random_color(host)
    end

    color
  end

  def set_color(metadata, host = false)

    color_key = metadata['labels']['kubernetes.io/name']
    color_key = metadata['labels']['k8s-app'] if color_key.nil?
    color_key = metadata['labels']['name'] if color_key.nil?
    color_key = metadata['name'] if color_key.nil?
    
    color = metadata['labels']['kubernetes.io/color'].nil? ? get_color(host) : "##{metadata['labels']['kubernetes.io/color']}"
    @colors[color_key] = color if @colors[color_key].nil?

    color_key
  end

  def getHosts
    hosts = {}
    @client.get_nodes.each { |node| 
      host_status = node[:status]['conditions'].select {|condition| condition['type'] == 'Ready' }

      if host_status[0]['status'] == 'True'
        # add a color
        color_key = set_color(node[:metadata], true)

        hosts[node[:metadata]['name']] = {
          :name => node[:metadata]['name'],
          :friendly_name => node[:metadata]['labels']['kraken-node'],
          :host => node[:metadata]['name'],
          :color => @colors[color_key]
        } 
      end
    }

    hosts
  end

  def getPods
    pods = {}
    @client.get_pods.each { |pod| 
      pods[pod[:spec]['nodeName']] = [] if pods[pod[:spec]['nodeName']].nil?

      # friendly name 
      friendly_name = pod[:metadata]['labels']['kubernetes.io/name']
      friendly_name = pod[:metadata]['labels']['k8s-app'] if friendly_name.nil?
      friendly_name = pod[:metadata]['labels']['name'] if friendly_name.nil?
      
      # setup color for this pod type
      color_key = set_color(pod[:metadata])

      # add the item
      pods[pod[:spec]['nodeName']].push(
        {
          :name => pod[:metadata]['name'],
          :friendly_name => friendly_name,
          :host => pod[:spec]['nodeName'],
          :color => @colors[color_key]
        }
      )

    }

    pods
  end

  def combine(hosts, pods)
    
    kube_data = {
      :name => 'kraken cluster',
      :color => '#FFFFFF',
      :children => []
    }

    hosts.each do |name, host_data|

      kube_data[:children].push(
        {
          :name => host_data[:name],
          :host => host_data[:name],
          :friendly_name => host_data[:friendly_name],
          :color => host_data[:color],
          :children => pods[host_data[:name]]
        }
      ) 
    end

    kube_data
  end

  def refresh
    host_info = getHosts()
    pod_info = getPods()
    pod_layout = combine(host_info, pod_info)

    send_event('kubernetes', pod_layout)
  end
end

proc = EventProcessor.new

SCHEDULER.every '5s', :allow_overlapping => false, :first_in => '1s' do |job|
  proc.refresh
end