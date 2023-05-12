@isTest(seeAllData=False)
public class DataMergeExtensionTest
{
	@testSetup
	static void setup()
	{
		Account testAccount = new Account(Name = 'Test Account', McaApp__Federal_Tax_ID_No__c = '123456789');
		insert testAccount;

		Lead testLead = new Lead(FirstName = 'John', LastName = 'Steinback', Company = 'Test Company', McaApp__Federal_Tax_ID_No__c = '987654321');
		insert testLead;
	}

	public class HttpResponseMockFactory implements HttpCalloutMock
	{
		protected Integer code;
		protected String status;
		protected String body;
		protected Map<String, String> responseHeaders;

		public HttpResponseMockFactory()
		{
			return;
		}

		public void code(Integer code)
		{
			this.code = code;
		}

		public void status(String status)
		{
			this.status = status;
		}

		public void body(String body)
		{
			this.body = body;
		}

		public void responseHeaders(Map<String, String> resposneHeaders)
		{
			this.responseHeaders = responseHeaders;
		}
		
		public HttpResponse respond(HTTPRequest req)
		{
			if (req.getEndpoint() == 'https://api.datamerch.com/api/v2/get_token')
				return this.buildMockAuthenticationResponse();
			
			if (req.getEndpoint().startsWith('https://api.datamerch.com/api/v2/merchants/') && this.body == null && this.status == null)
				return this.buildMockDataMerchNotesResponse();

			HttpResponse res = new HttpResponse();
			if (this.responseHeaders != null)
				for (String key : this.responseHeaders.keySet())
				{
					res.setHeader(key, this.responseHeaders.get(key));
				}
			res.setBody(this.body != null ? this.body : '');
			res.setStatusCode(this.code != null ? this.code : 0);
			res.setStatus(this.status != null ? this.status : '');
			return res;
		}

		public HttpResponse buildMockAuthenticationResponse()
		{
			HttpResponse response = new HttpResponse();
			response.setBody('{"token":"mock_authentication_key.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_`abcdefghijklmnopqrstuvwxyz"}');
			response.setHeader('content-type', 'application/json; charset=utf-8');
			response.setStatus('OK');
			response.setStatusCode(200);
			return response;
		}

		public HttpResponse buildMockDataMerchNotesResponse()
		{
			HttpResponse response = new HttpResponse();
			response.setBody('[\n  {\n    \"merchant\": {\n      \"fein\": \"12-3456789\",\n      \"legal_name\": \"ABC Company\",\n      \"dba\": \"\",\n      \"address\": null,\n      \"street1\": null,\n      \"street2\": null,\n      \"city\": \"Test City\",\n      \"state\": \"FL\",\n      \"business_phone\": \"\",\n      \"business_startdate\": null,\n      \"industry\": \"\",\n      \"notes\": [\n        {\n          \"note\": {\n            \"note\": \"Default\",\n            \"category\": \"Default\",\n            \"added_by\": \"Forward Financing\",\n            \"created_at\": \"2023-03-16T17:30:35.526Z\"\n          }\n        },\n        {\n          \"note\": {\n            \"note\": \"Testing \",\n            \"category\": \"Other\",\n            \"added_by\": \"Liberty Funding Solutions\",\n            \"created_at\": \"2023-03-16T12:34:55.894Z\"\n          }\n        },\n        {\n          \"note\": {\n            \"note\": \"Test Record \",\n            \"category\": \"Other\",\n            \"added_by\": \"DataMerch\",\n            \"created_at\": \"2023-03-16T11:45:13.264Z\"\n          }\n        }\n      ]\n    }\n  }\n]');
			response.setHeader('content-type', 'application/json; charset=utf-8');
			response.setStatus('OK');
			response.setStatusCode(200);
			return response;
		}
	}

	@isTest
	static void testExtensiOnOnAccount()
	{
		Test.setMock(HttpCalloutMock.class, new HttpResponseMockFactory());
		Test.startTest();
		Account testAccount = [SELECT Id, Name, McaApp__Federal_Tax_ID_No__c FROM Account WHERE Name = 'Test Account' LIMIT 1];
		ApexPages.StandardController stdController = new ApexPages.StandardController(testAccount);
		DataMergeExtension dataMergeExt = new DataMergeExtension(stdController);
		dataMergeExt.insertRecords();
		Test.stopTest();

		List<DataMerch_Note__c> dmNotes = [SELECT Id, Related_Account__c FROM DataMerch_Note__c WHERE Related_Account__c = :testAccount.Id];
		System.assertNotEquals(0, dmNotes.size(), 'DataMerch Notes should be inserted for Account');
	}

	@isTest
	static void testExtensiOnOnLead()
	{
		Test.setMock(HttpCalloutMock.class, new HttpResponseMockFactory());
		Test.startTest();
		Lead testLead = [SELECT Id, FirstName, LastName, McaApp__Federal_Tax_ID_No__c, McaApp__ISO__c FROM Lead WHERE LastName = 'Steinback' LIMIT 1];
		ApexPages.StandardController stdController = new ApexPages.StandardController(testLead);
		DataMergeExtension dataMergeExt = new DataMergeExtension(stdController);
		dataMergeExt.insertRecords();
		Test.stopTest();

		List<DataMerch_Note__c> dmNotes = [SELECT Id, Related_Lead__c FROM DataMerch_Note__c WHERE Related_Lead__c = :testLead.Id];
		System.assertNotEquals(0, dmNotes.size(), 'DataMerch Notes should be inserted for Lead');
	}

	@isTest
	static void testEmptyResponse()
	{
		HttpResponseMockFactory emptyResponse = new HttpResponseMockFactory();
		emptyResponse.body = emptyResponse.body = '[]';

		Test.setMock(HttpCalloutMock.class, emptyResponse);
		Test.startTest();
		Account testAccount = [SELECT Id, Name, McaApp__Federal_Tax_ID_No__c FROM Account WHERE Name = 'Test Account' LIMIT 1];
		ApexPages.StandardController stdController = new ApexPages.StandardController(testAccount);
		DataMergeExtension dataMergeExt = new DataMergeExtension(stdController);
		dataMergeExt.insertRecords();
		Test.stopTest();

		List<DataMerch_Note__c> dmNotes = [SELECT Id, Related_Account__c FROM DataMerch_Note__c WHERE Related_Account__c = :testAccount.Id];
		System.assertEquals(0, dmNotes.size(), 'DataMerch Notes should not be inserted for Account');
	}
}