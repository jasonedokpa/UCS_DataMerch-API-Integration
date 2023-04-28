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
	public List<DataMerch_Note__c> oldNotes { get; set; }
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
		this.oldNotes = [SELECT Id FROM DataMerch_Note__c WHERE Related_Account__c = :this.getAccountId()];
		this.newNotes = this.getCases(authKey);
	}

	public String AuthenticateWithDataMerch()
	{
		HttpRequest req = new HttpRequest();
		req.setEndpoint('https://api.datamerch.com/api/v2/get_token');
		req.setMethod('POST');
		req.setBody('{\n  \"auth\":\n  {\n    \"authentication_token\":\"' + API_tokens__mdt.get('Data Merch Authentication Data').Auth_Token__c + '\",\n    \"authentication_key\":\"' + API_tokens__mdt.get('Data Merch Authentication Data').Auth_Key__c + '\"\n  }\n}');
		req.setHeader('Accept', '*/*');
		req.setHeader('Content-Type', 'application/json');

		Http http = new Http();
		HTTPResponse res = http.send(req);
		System.debug(res.getBody());
		Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
		String authenticationKey = (String) responseMap.get('token');

		return authenticationKey;
	}

	public List<DataMerch_Note__c> getCases(String authenticationKey)
	{
		HttpRequest req = new HttpRequest();
		req.setEndpoint('https://api.datamerch.com/api/v2/merchants/' + record.get('McaApp__Federal_Tax_ID_No__c'));
		req.setMethod('GET');
		req.setHeader('Accept', '*/*');
		req.setHeader('Authorization', authenticationKey);

		Http http = new Http();
		HTTPResponse res = http.send(req);
		System.debug(res.getBody());

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
				newDataMerchNote.Created_At__c = (String) noteMap.get('created_at');
				newDataMerchNote.Added_By__c = (String) noteMap.get('added_by');
				newDataMerchNote.Related_Account__c = this.getAccountId();
				listOfDataMerchNotesInsert.add(newDataMerchNote);
			}

			System.debug(listOfDataMerchNotesInsert);
			return listOfDataMerchNotesInsert;
		}
	}

	public Id getAccountId()
	{
		if (sObjectType == 'Account')
			return DataMergeExtension.record.Id;

		if (sObjectType == 'Lead' && DataMergeExtension.record.get('McaApp__ISO__c') != null)
			return (Id) DataMergeExtension.record.get('McaApp__ISO__c');
		
		return null;
	}

	public void insertRecords()
	{
		delete this.oldNotes;
		insert this.newNotes;
		this.showButton = false;
	}
}