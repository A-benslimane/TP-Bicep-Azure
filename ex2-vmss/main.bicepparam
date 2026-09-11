using './main.bicep'

param prefix = 'abdel'
param location = 'westeurope'
param vmSize = 'Standard_D2s_v3'
param adminUsername = 'abdel'
param minInstances = 2
param maxInstances = 4

param sshPublicKey = '<SSH_PUBLIC_KEY>'
