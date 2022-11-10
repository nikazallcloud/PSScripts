#Install Correct Module for Identity Governance 
Install-Module -Name Microsoft.Graph

#Connect to Graph with Proper Scopes
Connect-MgGraph -Scopes "EntitlementManagement.ReadWrite.All"

#We will switch to the Beta Version of Graph
Select-MgProfile -Name "beta"

#Create Access Packages In Bulk
$AccessPackageArray = @("Accesspackage1", "Accesspackage2")

    foreach ($accesspackage in $AccessPackageArray) { New-MgEntitlementManagementAccessPackage -CatalogId $CatalogID -DisplayName $DisplayName -Description $Description}

#Get Access Token using App Reg

$ApplicationID = "App ID Goes Here"
$TenantDomainName = "Domain Name Goes here"
$Secret = Get-AzKeyVaultSecret -VaultName 'Vault where App reg secret is stored' -Name 'Your Keyvault Secret Name' -AsPlainText 


$Body = @{    
Grant_Type    = "client_credentials"
Scope         = "https://graph.microsoft.com/.default"
client_Id     = $ApplicationID
Client_Secret = $Secret
} 

$ConnectGraph = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantDomainName/oauth2/v2.0/token" `
-Method POST -Body $Body

$token = $ConnectGraph.access_token


#Rest Params

$restParams = @{
    Headers = @{
        Authorization = "Bearer $Token"
    }
}
 

#Configuration

$graphBase = "https://graph.microsoft.com/beta"
$endpoints = @{
    accessPackageCatalogs = "{0}/identityGovernance/entitlementManagement/accessPackageCatalogs" -f $graphBase
    accessPackages = "{0}/identityGovernance/entitlementManagement/accessPackages" -f $graphBase
    users = "{0}/users" -f $graphBase
    groups = "{0}/groups" -f $graphBase
    accessPackageAssignmentPolicies = "{0}/identityGovernance/entitlementManagement/accessPackageAssignmentPolicies" -f $graphBase
    me = "{0}/me" -f $graphBase
}

 
#Use Array, Store Access Packages from Catalog in Variable or use CSV

#Get all access packages in this catalog
$currentAccessPackages = Invoke-RestMethod $endpoints.accessPackages @restParams | 
    Select-Object -ExpandProperty Value | 
    Where-Object catalogId -eq "Catalog ID Goes here" 

 
#Create Access Package Policies
$AccessPackagesArray = @("AccessPackage1", "Accesspackage2", "Accesspackage3")

foreach ($AccessPackage in $AccessPackagesArray) {

    Write-Host "Creating Policy for Access Package $AccessPackage" -ForegroundColor Green
    $body = @{
        accessPackageId = "$AccessPackage"
        displayName = "Test"
        description = "Test"
        durationInDays = 0
        canExtend = $false
        requestorSettings = @{
            acceptRequests = $true
            scopeType = "AllExistingDirectoryMemberUsers"
            allowedRequestors = @()
        }
        accessReviewSettings = $null
        requestApprovalSettings = @{
            isApprovalRequired = $true
            isApprovalRequiredForExtension = $false
            isRequestorJustificationRequired = $true
            approvalMode = "Serial"
            approvalStages = @(
                @{
                    approvalStageTimeOutInDays = 14
                    isApproverJustificationRequired = $true
                    isEscalationEnabled = $false
                    escalationTimeInMinutes = 0
                    primaryApprovers = @(
                        @{
                            "@odata.type" = "#microsoft.graph.singleUser"
                            id = "objectidofusergoeshere"
                            description = "Admin"
                            isBackup = $false
                        }
                    )
                }
            )
        }
    }
    Invoke-RestMethod $endpoints.accessPackageAssignmentPolicies @restParams -Method Post -Body ($body | 
        ConvertTo-Json -Depth 10) -ContentType "application/json" | Out-Null

}
