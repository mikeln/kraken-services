
require 'kubeclient'
require 'paleta'

class EventProcessor

  MAX_NS_COLORS = 20
  MAX_POD_NS_COLORS = 20
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
    @ns_palette = Paleta::Palette.generate(:type => :random, :size => MAX_NS_COLORS)
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

  def get_pod_color(pod, color_key)
	  # check for override in resources...only if color isn't already set
    color = @colors[color_key]
    if color.nil?
      labels = getLabels(pod[:metadata])
      if !labels['cagby.io/color'].nil? 
        color = "##{labels['cagby.io/color']}"
      end
    end
    color
  end

#  def set_pod_color(pod, color)
#    labels = getLabels(pod[:metadata])
#    color_key = get_pod_color_key(pod)
#
#    if @colors[color_key].nil?
#      color = labels['cagby.io/color'].nil? ? "##{color}" : "##{labels['cagby.io/color']}"
#      @colors[color_key] = color
#    end
#
#    color_key
#  end

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
    #
    # NOTE: The grouping of the pods by namespace, does not preserve any previous ordering of namesapce names.
    # NOTE: e.g. If a new Namespace was added, it may be grouped/sorted before the namespaces that were already
    # NOTE: present.   At which point the ns_i  is not a good key for color data.   Need to map ns -> color, and
    # NOTE: also keep track of still available colors (so we use the all before recycling (if more than 20)).
    # NOTE: So, since we only need the namespace random palette as the source for the base color of each namespace
    # NOTE: palette...we can just key the namespace (pods) palette by name instead of by index.

    pods_by_namespace.keys.each_with_index do |ns, ns_i|
      pods_in_namespace = pods_by_namespace[ns]

      # create the pod palette based on the namespace color...but only for those that don't already have a palette
      current_ns_palette = @ns_palette
      # dim kube-system pods / make all other pods stand out more
      if ns == 'kube-system'
        curent_ns_palette = @ns_palette.map { |c| c.saturation = 10; c.lighten!(20) }
      else
        curent_ns_palette = @ns_palette.map { |c| c.saturation = 80; c.darken!(20) }
      end

      current_pod_palette = @pod_palettes[ns]
      if current_pod_palette.nil?
        # need to create a new palette for thie NS
        # Use a fixed size and moludo it to limit access
        #
        # Need to map the name of used indices, so we choose a new base color for this namespace's palette
        # Use some math here... size of pod_palettes before the add gives us a correct 0-(n-1) range.
        #
        new_ns_i = @pod_palettes.length
        # make sure we don't exceed the palette bounds
        ns_palette_i = new_ns_i % MAX_NS_COLORS

        current_pod_palette = Paleta::Palette.generate(:type => :shades, :from => :color, :size => MAX_POD_NS_COLORS, :color => current_ns_palette[ns_palette_i] )
	@pod_palettes[ns] = current_pod_palette
	#puts "New pod Palette[#{ns}]: #{ns_palette_i} c: #{current_ns_palette[ns_palette_i].hex} - "
	#current_pod_palette.each_with_index{|v,k| puts "++ #{k}:#{v.hex}"}
      end


      pods_in_namespace.each_with_index do |pod, pod_i|
        pods_by_node[pod[:spec]['nodeName']] = [] if pods_by_node[pod[:spec]['nodeName']].nil?
        color_key = get_pod_color_key(pod)
	# see if we already have a color for this key
        color = get_pod_color(pod, color_key)
	# if still nil, pick from palette
        if color.nil?
          # The shades palette tends be increasing values...jump around for better color dist
          # NOTE: This has the same issue with the list of Pods chaning position, but since it is in the
          # NOTE: same palette, we'll accept the cases where we end up with the same or similar colros.
          pod_palette_i = (3*pod_i) % MAX_POD_NS_COLORS
	  color = "##{current_pod_palette[pod_palette_i].hex}"
        end
	#puts "-- #{pod_i}: #{pod_palette_i} c: #{color} - #{pod[:metadata]['name']}"

        # setup color for this pod type
        # color_key = set_pod_color(pod, color)
	#
	# Set the color  to remember (resets if already set...sloppy)
	@colors[color_key] = color

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
