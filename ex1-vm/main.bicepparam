using './main.bicep'

param prefix = 'abdel'
param location = 'francecentral'
param vmSize = 'Standard_D2s_v3'
param adminUsername = 'abdel'

param sshPublicKey = '<SSH_PUBLIC_KEY>'
param sourceIp = '<YOUR_PUBLIC_IP>/32'
