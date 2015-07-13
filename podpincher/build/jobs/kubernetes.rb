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

  def get_random_color
    @h += @golden_ratio_conjugate
    @h %= 1
    color = hsv_to_rgb(@h, 0.99, 0.99)

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

  def getHosts
    hosts = {}
    @client.get_nodes.each { |node| 
      hosts[node[:metadata]['name']] = {
        :name => node[:metadata]['name'],
        :friendly_name => node[:metadata]['labels']['kraken-node'],
        :host => node[:metadata]['name']
      } 
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
      
      # add a color
      if friendly_name.nil?
        @colors[pod[:metadata]['name']] = get_random_color if @colors[pod[:metadata]['name']].nil?
      else
        @colors[friendly_name] = get_random_color if @colors[friendly_name].nil?
      end
      # add the item
      pods[pod[:spec]['nodeName']].push(
        {
          :name => pod[:metadata]['name'],
          :friendly_name => friendly_name,
          :host => pod[:spec]['nodeName'],
          :color => friendly_name.nil? ? @colors[pod[:metadata]['name']] : @colors[friendly_name]
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

      # add a color
      # @colors[host_data[:name]] = get_random_color if @colors[host_data[:name]].nil?

      kube_data[:children].push(
        {
          :name => host_data[:name],
          :host => host_data[:name],
          :friendly_name => host_data[:friendly_name],
          :color => '#C0C0C0',
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