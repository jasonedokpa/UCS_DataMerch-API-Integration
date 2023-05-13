Lead debugLead = [SELECT Id, Name, McaApp__Federal_Tax_ID_No__c FROM Lead WHERE Id = '00Q7h00000AWpHdEAL'];
ApexPages.StandardController stdController = new ApexPages.StandardController(debugLead);
DataMergeExtension dataMergeExt = new DataMergeExtension(stdController);
dataMergeExt.insertRecords();