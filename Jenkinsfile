node('master') {
  try {
    stage 'Downloading sources'
    git credentialsId: 'jenkins-ssh', url: 'git@github.com:samsung-cnct/kraken-services.git'
    stage 'Building and publishing images'
    docker.withServer('unix:///run/docker.sock') {

      stage 'Building load generator test service image'
      def framework = docker.build("samsung_ag/trogdor-framework:${env.BUILD_NUMBER}", "loadtest/build/trogdor-framework")
      stage 'Pushing load generator test service image'
      docker.withRegistry('https://quay.io/v1', 'quay-io') {
        framework.push()
        framework.push 'latest'
      }

      stage 'Building load generator image'
      def load_gen = docker.build("samsung_ag/trogdor-load-generator:${env.BUILD_NUMBER}", "loadtest/build/trogdor-load-generator")
      stage 'Pushing load generator image'
      docker.withRegistry('https://quay.io/v1', 'quay-io') {
        load_gen.push()
        load_gen.push 'latest'
      }

      stage 'Building grafana image'
      def grafana = docker.build("samsung_ag/grafana:${env.BUILD_NUMBER}", "cluster-monitoring/build/grafana")
      stage 'Pushing grafana image'
      docker.withRegistry('https://quay.io/v1', 'quay-io') {
        grafana.push()
        grafana.push 'latest'
      }

      stage 'Building podpincher image'
      def podpincher = docker.build("samsung_ag/podpincher:${env.BUILD_NUMBER}", "podpincher/build/podpincher")
      stage 'Pushing podpincher image'
      docker.withRegistry('https://quay.io/v1', 'quay-io') {
        podpincher.push()
        podpincher.push 'latest'
      }

      stage 'Building promdash image'
      def promdash = docker.build("samsung_ag/promdash:${env.BUILD_NUMBER}", "prometheus/build/promdash")
      stage 'Pushing promdash image'
      docker.withRegistry('https://quay.io/v1', 'quay-io') {
        promdash.push()
        promdash.push 'latest'
      }

      stage 'Building prometheus image'
      def prometheus = docker.build("samsung_ag/prometheus:${env.BUILD_NUMBER}", "prometheus/build/prometheus")
      stage 'Pushing prometheus image'
      docker.withRegistry('https://quay.io/v1', 'quay-io') {
        prometheus.push()
        prometheus.push 'latest'
      }
    }
  } catch (e) {
    throw e
  }
}
