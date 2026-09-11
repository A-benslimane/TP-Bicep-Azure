param prefix string = 'abdel'
param location string = resourceGroup().location

param mainCpu int = 1
param mainMemory int = 1

param sidecarCpu int = 1
param sidecarMemory int = 1

var containerGroupName = '${prefix}-aci'
var dnsLabel = '${prefix}-aci-${uniqueString(resourceGroup().id)}'

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location

  properties: {
    osType: 'Linux'
    restartPolicy: 'Always'

    ipAddress: {
      type: 'Public'

      ports: [
        {
          protocol: 'TCP'
          port: 80
        }
      ]

      dnsNameLabel: dnsLabel
    }

    containers: [
      {
        name: 'web'

        properties: {
          image: 'mcr.microsoft.com/azuredocs/aci-helloworld:latest'

          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
          ]

          resources: {
            requests: {
              cpu: mainCpu
              memoryInGB: mainMemory
            }
          }
        }
      }

      {
        name: 'sidecar'

        properties: {
          image: 'mcr.microsoft.com/azurelinux/base/core:3.0'

          command: [
            '/bin/sh'
            '-c'
            'while true; do echo "$(date) - sidecar actif"; sleep 30; done'
          ]

          resources: {
            requests: {
              cpu: sidecarCpu
              memoryInGB: sidecarMemory
            }
          }
        }
      }
    ]
  }
}

output fqdn string = containerGroup.properties.ipAddress.fqdn
output publicIp string = containerGroup.properties.ipAddress.ip
output webUrl string = 'http://${containerGroup.properties.ipAddress.fqdn}'
