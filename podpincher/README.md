# podpincher

A web UI visualising pod - to - host distribution in a kraken cluster.

## Compatibility

Kubernetes API v1 (will not work with v1beta3)

## Setup
### local cluster:
```sh
kraken local up
kubectl --cluster=local create -f other
```
Then wait for the pods to exit Pending state and open http://172.16.1.103:30977 in your browser
### aws cluster

First make sure your aws settings.yaml has the elastic load balancer configured correctly:
```sh
elb:
    name: your_elb_name
    dns_name: something.kubeme.io
    listeners:
      - elb_port: 80
        forwarding_to: 30061
        protocol: HTTP
      - elb_port: 8080                # add this section to the listeners array
        forwarding_to: 30977          # add this section to the listeners array
        protocol: HTTP                # add this section to the listeners array
    healthy_threshold: 2
    unhealthy_threshold: 3
    timeout: 5
    interval: 30
    heathcheck_port: 30977
```
then:
```sh
kraken aws up
kubectl --cluster=aws create -f other
```

Then wait for the pods to exit Pending state and open http://something.kubeme.io:8080 in your browser

### nuc cluster:
```sh
kraken local up
kubectl --cluster=nuc create -f other
```
Then wait for the pods to exit Pending state and open http://ip of a node:30977 in your browser

## Changes for Better Pod Color
### Description
These changes were made to better demonstrate Chaos Monkey removal of pods.
### Changes
Many changes where made in the `jobs/kubernetes.rb` file.  Many quick demo quick fixes had resulted in some pretty bad memory usage and other inefficiencies.  The main upgrades for the chaos demos follow:

* An initial color palette of 20 random colors  is created for Kubernetes Namespaces.  The color palette is accessed via the namespace name index modulo 20.  In this way colors may be reused if there are more than 20 namesapces in a given cluster.  However, these colors are used only as the base Palette colors for any pods that may be displayed in that namespace.
* When a Pod in a new namespace is detected, a new 20 color shade palette based on the choosen namespace color is created.  Shade palettes go from light to dark, so initially there was some logic to traverse the colors by 3s to provide more of a contrast, but it was determined that sequential usage provided enough visual differences.  The color for a pod is choosed based on an incremental pod count modulo 20.  The issue that occurred is that when a steady state of pod dies/pod starts occurs, the colors always index out the same and would end up with a single color ring.  By incrementing the pod count, we get a new different color.( until we've exceeded 20 pods but then the odds of duplicates appearing side by side is acceptable)
* see the ruby paleta gem for more info on random color palettes vs shaded palettes, etc.
* The pods were originally indexed by the index value, but that could change between reads depending on the name of the pods.  So the pod indexing was changed to the "ugly name" so it would always be unique.  In this way the pods stay the same color they always were.
* Detection was added for termating pods, and any pods meeting that criteria are changed to a bright red and the name has "Terminating: " added to the mouse over display.
* The `widgets/kubernetes/zoomable_sunburst.coffee` had an issue that color changes were not propogating.  Adding `+ d.color` fixed that (non-obvious fix)
* The color palette system is NOT implemented when you specify a specific color for a pod.  (Indeed, many of these specify color versions were not tested so YMMV)

