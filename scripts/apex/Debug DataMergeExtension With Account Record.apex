Account debugAccount = [SELECT Id, Name, McaApp__Federal_Tax_ID_No__c FROM Account WHERE Id = '0017h00000tRZfUAAW'];
ApexPages.StandardController stdController = new ApexPages.StandardController(debugAccount);
DataMergeExtension dataMergeExt = new DataMergeExtension(stdController);
dataMergeExt.insertRecords();
