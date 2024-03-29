/*
Name		: DataMergeExtension
Developer	: jason@banjaxed.com (Jason Edokpa)
Date		: 27th April 2023
Description	: An extension for the Account and Lead standard controllers that is used to handle the callouts to the DataMerch API and creating the new "DataMerch Note" records
*/

public with sharing class DataMergeExtension
{
	private static SObject record;
	private static String sObjectType;
	public Boolean isLoading { get; set; }
	public Boolean showButton { get; set; }
	public Boolean emptyResponseReturned { get; set; }
	private List<DataMerch_Note__c> oldNotes;
	public List<DataMerch_Note__c> newNotes { get; set; }

	public DataMergeExtension(ApexPages.StandardController controller)
	{
		Id recordId = controller.getId();
		this.showButton = true;

		//determine whether it is an Account or a Lead
		if (recordId != null)
		{
			switch on String.valueOf(recordId.getSObjectType())
			{
				when 'Account'
				{
					record = [SELECT FIELDS(STANDARD), McaApp__Federal_Tax_ID_No__c FROM Account WHERE Id = :recordId LIMIT 1];
					DataMergeExtension.sObjectType = 'Account';
				}
				when 'Lead'
				{
					record = [SELECT FIELDS(STANDARD), McaApp__Federal_Tax_ID_No__c, McaApp__ISO__c FROM Lead WHERE Id = :recordId LIMIT 1];
					DataMergeExtension.sObjectType = 'Lead';
				}
			}
		}

		System.debug(record);
		String authKey = this.AuthenticateWithDataMerch();
		String relationshipField = 'Related_' + DataMergeExtension.sObjectType + '__c';
		this.oldNotes = Database.query('SELECT Id FROM DataMerch_Note__c WHERE ' + relationshipField + ' = :recordId');
		this.newNotes = this.getCases(authKey);
	}

	public String AuthenticateWithDataMerch()
	{
		HttpRequest req = new HttpRequest();
		req.setEndpoint('https://api.datamerch.com/api/v2/get_token');
		req.setMethod('POST');
		req.setBody('{\n  \"auth\":\n  {\n    \"authentication_token\":\"6b87e22ffe03174a9a10d503d9419bbc\",\n    \"authentication_key\":\"e8856b0b5b8606133b50\"\n  }\n}');
		req.setHeader('Accept', '*/*');
		req.setHeader('Content-Type', 'application/json');

		Http http = new Http();
		HttpResponse res = http.send(req);
		System.debug('Aunthentication response: ' + res.getBody());
		Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

		return (String) responseMap.get('token');
	}

	public List<DataMerch_Note__c> getCases(String authenticationKey)
	{
		HttpRequest req = new HttpRequest();
		req.setEndpoint('https://api.datamerch.com/api/v2/merchants/' + record.get('McaApp__Federal_Tax_ID_No__c'));
		req.setMethod('GET');
		req.setHeader('Accept', '*/*');
		req.setHeader('Authorization', authenticationKey);

		Http http = new Http();
		HttpResponse res = http.send(req);
		System.debug('Merchant response: ' + res.getBody());

		if (((List<Object>) JSON.deserializeUntyped(res.getBody())).size() == 0)
		{
			this.emptyResponseReturned = true;
			System.debug('Emtpy response returned.');
			return new List<DataMerch_Note__c>();
		}
		else	
		{	
			this.emptyResponseReturned = false;
			// Parse the JSON string into an Apex Map
			Object responseMap = ((List<Object>) JSON.deserializeUntyped(res.getBody())).get(0);

			// Get the "notes" field as a list of objects
			List<Object> notesList = (List<Object>) ((Map<String,Object>) ((Map<String,Object>) responseMap).get('merchant')).get('notes');
			
			//Create a list of DataMerch Note records to insert
			List<DataMerch_Note__c> listOfDataMerchNotesInsert = new List<DataMerch_Note__c>();
			for (Object note : notesList)
			{
				Map<String, Object> noteMap = (Map<String, Object>) ((Map<String, Object>) note).get('note');
				DataMerch_Note__c newDataMerchNote = new DataMerch_Note__c();
				newDataMerchNote.Category__c = (String) noteMap.get('category');
				newDataMerchNote.Note__c = (String) noteMap.get('note');
				newDataMerchNote.Created_At__c = Datetime.valueOf(((String) noteMap.get('created_at')).replace('T', ' '));
				newDataMerchNote.Added_By__c = (String) noteMap.get('added_by');
				if (DataMergeExtension.sObjectType == 'Account')
					newDataMerchNote.Related_Account__c = DataMergeExtension.record.Id;
				if (DataMergeExtension.sObjectType == 'Lead')
					newDataMerchNote.Related_Lead__c = DataMergeExtension.record.Id;
				listOfDataMerchNotesInsert.add(newDataMerchNote);
			}

			System.debug('DataMerch Note records: ' + listOfDataMerchNotesInsert);
			return listOfDataMerchNotesInsert;
		}
	}

	public void insertRecords()
	{
		delete this.oldNotes;
		insert this.newNotes;
		this.showButton = false;
	}
}