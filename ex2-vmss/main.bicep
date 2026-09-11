param prefix string = 'abdel'
param location string = resourceGroup().location
param vmSize string = 'Standard_D2s_v3'

@secure()
param sshPublicKey string

param adminUsername string = 'abdel'

@minValue(2)
param minInstances int = 2

@minValue(2)
param maxInstances int = 4

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${prefix}-vmss-nsg'
  location: location

  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${prefix}-vmss-vnet'
  location: location

  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'subnet-vmss'

  properties: {
    addressPrefix: '10.1.1.0/24'

    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// =======================
// IP PUBLIQUE
// =======================

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${prefix}-vmss-pip'
  location: location

  sku: {
    name: 'Standard'
  }

  properties: {
    publicIPAllocationMethod: 'Static'

    dnsSettings: {
      domainNameLabel: '${prefix}-vmss-${uniqueString(resourceGroup().id)}'
    }
  }
}

// =======================
// LOAD BALANCER
// =======================

resource loadBalancer 'Microsoft.Network/loadBalancers@2024-05-01' = {
  name: '${prefix}-lb'
  location: location

  sku: {
    name: 'Standard'
  }

  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]

    backendAddressPools: [
      {
        name: 'backendPool'
      }
    ]

    probes: [
      {
        name: 'httpProbe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]

    loadBalancingRules: [
      {
        name: 'httpRule'
        properties: {
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80

          frontendIPConfiguration: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/frontendIPConfigurations',
              '${prefix}-lb',
              'frontend'
            )
          }

          backendAddressPool: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/backendAddressPools',
              '${prefix}-lb',
              'backendPool'
            )
          }

          probe: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/probes',
              '${prefix}-lb',
              'httpProbe'
            )
          }

          enableFloatingIP: false
          idleTimeoutInMinutes: 4
        }
      }
    ]
  }
}

// =======================
// VM SCALE SET
// =======================

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2024-07-01' = {
  name: '${prefix}-vmss'
  location: location

  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: 2
  }

  properties: {
    overprovision: false

    upgradePolicy: {
      mode: 'Automatic'
    }

    virtualMachineProfile: {
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }

        osDisk: {
          createOption: 'FromImage'

          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      }

      osProfile: {
        computerNamePrefix: 'vmss'
        adminUsername: adminUsername

        linuxConfiguration: {
          disablePasswordAuthentication: true

          ssh: {
            publicKeys: [
              {
                path: '/home/${adminUsername}/.ssh/authorized_keys'
                keyData: sshPublicKey
              }
            ]
          }
        }
      }

      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic'
            properties: {
              primary: true

              ipConfigurations: [
                {
                  name: 'ipconfig'

                  properties: {
                    subnet: {
                      id: subnet.id
                    }

                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId(
                          'Microsoft.Network/loadBalancers/backendAddressPools',
                          '${prefix}-lb',
                          'backendPool'
                        )
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }

      extensionProfile: {
        extensions: [
          {
            name: 'install-nginx'

            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.1'
              autoUpgradeMinorVersion: true

              settings: {
                commandToExecute: 'bash -c "cloud-init status --wait || true; apt-get update && apt-get install -y nginx && echo \'<h1>Serveur VMSS : $(hostname)</h1>\' > /var/www/html/index.html && systemctl enable --now nginx"'
              }
            }
          }
        ]
      }
    }
  }

  dependsOn: [
    loadBalancer
  ]
}

// =======================
// AUTOSCALE
// =======================

resource autoscale 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${prefix}-vmss-autoscale'
  location: location

  properties: {
    enabled: true
    targetResourceUri: vmss.id

    profiles: [
      {
        name: 'cpu-autoscale'

        capacity: {
          minimum: string(minInstances)
          maximum: string(maxInstances)
          default: '2'
        }

        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmss.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }

            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }

          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: vmss.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }

            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
  }
}

// =======================
// OUTPUTS
// =======================

output publicIpAddress string = publicIp.properties.ipAddress
output fqdn string = publicIp.properties.dnsSettings.fqdn
output webUrl string = 'http://${publicIp.properties.dnsSettings.fqdn}'
output vmssName string = vmss.name
