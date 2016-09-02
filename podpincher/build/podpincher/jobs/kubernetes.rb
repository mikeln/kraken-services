# encoding: utf-8
require 'kubeclient'
require 'paleta'

class EventProcessor

  def initialize
    ssl_options = { verify_ssl: OpenSSL::SSL::VERIFY_NONE }
    @client = Kubeclient::Client.new ENV.fetch('KUBERNETES_API_URL', 'https://kubernetes:443/api/'), ENV.fetch('KUBERNETES_API_VER', 'v1'), ssl_options: ssl_options
    @colors = {}
    @zone_colors = {
      r: "cc0000",
      g: "00cc00",
      b: "0000cc",
      none: "888888"
    }.map { |k,v| [k, Paleta::Color.new(:hex, v)] }.to_h
    @disabled_node_color = Paleta::Color.new(:hex, "444444")
    @ns_palette = Paleta::Palette.generate(:type => :random, :size => 20)
    @pod_palettes = Hash.new
  end

  def getLabels(metadata)
    if metadata.nil? || metadata['labels'].nil?
      {}
    else
      metadata['labels']
    end
  end

  def get_friendly_pod_name(pod)
    labels = getLabels(pod[:metadata])
    key = ['kubernetes.io/name', 'k8s-app', 'app', 'name'].find { |k| not labels[k].nil? }
    key.nil? ? pod[:metadata]['name'] : labels[key]
  end

  def get_pod_color_key(pod)
   # change this to index on each pod name...vs just the friendly type
   # labels = getLabels(pod[:metadata])
   # key = ['kubernetes.io/name', 'k8s-app', 'app', 'name'].find { |k| not labels[k].nil? }
   # key.nil? ? pod[:metadata]['name'] : labels[key]
    key = pod[:metadata]['name']
  end

  def get_pod_color(pod)
    # TODO: manual color overrides / label color overrides / annotation color overrides
    nil
  end

  def set_pod_color(pod, color)
    labels = getLabels(pod[:metadata])
    color_key = get_pod_color_key(pod)

    if @colors[color_key].nil?
      color = labels['cagby.io/color'].nil? ? "##{color}" : "##{labels['cagby.io/color']}"
      @colors[color_key] = color
    end

    color_key
  end

  def get_friendly_node_name(node)
    labels = getLabels(node[:metadata])
    key = ['kraken-node', 'name'].find { |k| not labels[k].nil? }
    key.nil? ? node[:metadata]['name'] : labels[key]
  end

  def get_node_color(node)
    labels = getLabels(node[:metadata])
    zone = labels['cagby.io/zone']
    if zone.nil?
      zone = "none"
    end
    color = @zone_colors.fetch(zone.downcase.to_sym, @zone_colors[:none])
    host_status = node[:status]['conditions'].select { |condition| condition['type'] == 'Ready' }
    if host_status[0]['status'] != 'True'
      color = @disabled_node_color
    end
    color
  end

  def get_namespaces
    namespaces = {}
    kube_namespaces = @client.get_namespaces
    # TODO: implement if we need this
    namespaces
  end

  def get_nodes_by_node
    nodes_by_node = {}
    kube_nodes = @client.get_nodes
    kube_nodes.each_with_index do |node, index|
      host_status = node[:status]['conditions'].select { |condition| condition['type'] == 'Ready' }
      host_color = get_node_color(node)
      nodes_by_node[node[:metadata]['name']] = {
        name: node[:metadata]['name'],
        friendly_name: get_friendly_node_name(node),
        host: node[:metadata]['name'],
        color: "##{host_color.hex}"
      }
    end
    nodes_by_node
  end

  def get_pods_by_node
    pods_by_node = {}
    all_pods = @client.get_pods
    pods_by_namespace = all_pods.group_by { |pod| pod[:metadata]['namespace'] }
    # original create a different color for each pod instance
    #palette = Paleta::Palette.generate(:type => :random, :size => all_pods.length)
    # create a random palteet by namespace.
    # then vary the color within that namespace for each pod
    # HOWEVER, we do not want to regenerate the palette every time...they colors potentially can change incorrectly.
    # so we are going to cheat and create a namespace palette for up to N namespaces
    # SEE THE INITIALIZER at the top! - MLN 
    #@ns_palette = Paleta::Palette.generate(:type => :random, :size => pods_by_namespace.length)

    pods_by_namespace.keys.each_with_index do |ns, ns_i|
      pods_in_namespace = pods_by_namespace[ns]

      # create the pod palette based on the namespace color...but only for those that don't already have a palette
      current_ns_palette = @ns_palette
      if ns == 'kube-system'
        curent_ns_palette = @ns_palette.map { |c| c.saturation = 10; c.lighten!(20) }
      else
        curent_ns_palette = @ns_palette.map { |c| c.saturation = 80; c.darken!(20) }
      end
      current_pod_palette = @pod_palettes[ns]
      if current_pod_palette.nil?
        # need to create a new palette for thie NS
        # dim kube-system pods / make all other pods stand out more
        # WARNING: this will change the values every time!
        current_pod_palette = Paleta::Palette.generate(:type => :shades, :from => :color, :size => pods_in_namespace.length, :color => current_ns_palette[ns_i] )
	@pod_palettes[ns] = current_pod_palette
      else
        # check to see if we need to add to the palette for this namespace..i.e more pods were added
        if current_pod_palette.size < pods_in_namespace.length 
		# shortcut...TODO:really need to add to the palette, NOT rebuild it
          current_pod_palette = Paleta::Palette.generate(:type => :shades, :from => :color, :size => pods_in_namespace.length, :color => current_ns_palette[ns_i] )
	  @pod_palettes[ns] = current_pod_palette
	end
      end

      pods_in_namespace.each_with_index do |pod, pod_i|
        pods_by_node[pod[:spec]['nodeName']] = [] if pods_by_node[pod[:spec]['nodeName']].nil?
        color_key = get_pod_color_key(pod)
	# NOTE: overriding the color will lose the shanding
        color = get_pod_color(pod)
        if color.nil?
          color = current_pod_palette[pod_i].hex
        end

        # setup color for this pod type
        color_key = set_pod_color(pod, color)

        # add the item
        pods_by_node[pod[:spec]['nodeName']].push(
          {
            name: pod[:metadata]['name'],
            friendly_name: get_friendly_pod_name(pod),
            host: pod[:spec]['nodeName'],
            color: @colors[color_key]
          }
        )
      end
    end

    pods_by_node
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
          name: host_data[:name],
          host: host_data[:name],
          friendly_name: host_data[:friendly_name],
          color: host_data[:color],
          children: pods[host_data[:name]]
        }
      )
    end

    kube_data
  end

  def refresh
    namespace_info = get_namespaces()
    nodes_by_node = get_nodes_by_node
    pods_by_node = get_pods_by_node
    pod_layout = combine(nodes_by_node, pods_by_node)

    send_event('kubernetes', pod_layout)
  end
end

proc = EventProcessor.new

SCHEDULER.every '5s', :allow_overlapping => false, :first_in => '1s' do |job|
  proc.refresh
end
