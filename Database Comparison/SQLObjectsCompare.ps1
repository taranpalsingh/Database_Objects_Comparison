CLS


##  Gives YES if the files match, NO if it doesn't matches and Not present if it is not present in that server.

############################################  Too be edited ############################################


Import-Module "C:\Users\Taran\Desktop\Database Comparison\Join.ps1"


##  Enter your csv file's path here ending with '\'
$csvPath = "C:\Users\masim\Desktop\Database Comparison\"


##  Enter your Primary server's name here ending with '\'
$primaryServer = "Feeds"


##  Enter the names of the servers here separated with ','ending with '\'
[String[]] $servers   = @("Feeds1","Feeds2", "Feeds3"); 


############################################  Too be edited ############################################

$mergedArr  =  New-Object System.Collections.Generic.List[System.Object]
$objArr     =  New-Object System.Collections.Generic.List[System.Object]
$headers    =  New-Object System.Collections.Generic.List[System.Object]

function Invoke-Sqlcmd2
{
	param(
	[string]$ServerInstance,
	[string]$Query,
	[Int32]$QueryTimeout=600
	)

	$conn = new-object System.Data.SqlClient.SQLConnection
	$conn.ConnectionString=”Server={0};Integrated Security=True” -f $ServerInstance,$Database
	$conn.Open()
	$cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn)
	$cmd.CommandTimeout=$QueryTimeout
	$ds = New-Object system.Data.DataSet
	$da = New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
	[void]$da.fill($ds)
	$ds.Tables[0]
	$conn.Close()
}


$sqlScript = "
	DECLARE @SqlStmt varchar(MAX)
	DECLARE @DbName      varchar(128)
	DECLARE @DbLoop int

	CREATE TABLE #definitions ( 		
	   [ObjectName]  VARCHAR (200) NULL,
	   [type]          VARCHAR (100)  NULL,
	   [definition]  NVARCHAR(MAX)  NULL
	);

	CREATE TABLE #DatabaseList (
	       Id            INT IDENTITY(1,1),
	       DbName  VARCHAR (128)
	);

	INSERT INTO #DatabaseList(DBName)
	SELECT name FROM sys.databases d WHERE d.database_id > 4 AND state_desc = 'ONLINE'       					
	       
	SET @DbLoop = SCOPE_IDENTITY()
	       
	WHILE @DbLoop >0
	BEGIN
	              
	       SELECT @DbName = DbName FROM #DatabaseList WHERE Id = @DbLoop

	       SET @SqlStmt = '
	              INSERT INTO #definitions ([ObjectName],[type],[definition])
	              SELECT '''+@DBName+'''+ ''.'' + s.name + ''.'' + o.name AS ObjectName,o.type_desc,sm.definition 			
	              FROM '+@DBName+'.sys.sql_modules sm
	              INNER JOIN '+@DBName+'.sys.objects o ON o.object_id = sm.object_id
	              INNER JOIN '+@DBName+'.sys.schemas s ON s.schema_id = o.schema_id'
	              
	       EXEC(@SqlStmt)
	              
	       SET @DbLoop = @DbLoop-1																				
	END

	SELECT [ObjectName],[type],[definition] FROM #definitions;

	DROP TABLE #DatabaseList
	DROP TABLE #definitions
	" 



$table1 = invoke-sqlcmd2 $primaryServer $sqlScript	

Write-Output ("###################################  " + $primaryServer)


foreach($server in $servers) 
{ 
    $table2 = invoke-sqlcmd2 $server $sqlScript
	Write-Output ("###################################  " + $server)
	$merged = Join-Object -Left $table1 -Right $table2 -LeftJoinProperty ObjectName -RightJoinProperty ObjectName -Prefix secondary_
	$mergedArr.Add($merged)	
}

$count = 0;
foreach ($x in $merged) { $count++}

$merges = 0;
foreach ($x in $servers) { $merges++}


for($i = 0; $i -lt $count; $i++){
	$obj = New-Object psobject
	$obj | Add-Member -MemberType NoteProperty -Name ($primaryServer) -Value $mergedArr[0][$i].ObjectName.Split(".")[0]
	$obj | Add-Member -MemberType NoteProperty -Name "File Name" -Value ($mergedArr[0][$i].ObjectName.Split(".")[1]+"."+$mergedArr[0][$i].ObjectName.Split(".")[2])
	$obj | Add-Member -MemberType NoteProperty -Name "Object Type" -Value $mergedArr[0][$i].type
	
	for($j = 0; $j -lt $merges; $j++){
		if($mergedArr[$j][$i].secondary_definition){
			if($mergedArr[$j][$i].definition -eq $mergedArr[$j][$i].secondary_definition){
				$match = "Yes"
			}
			else{
				$match = "No"
			}
		}
		else{
				$match = "Not Present"
		}
		$obj | Add-Member -MemberType NoteProperty -Name $servers[$j] -Value $match 
	}
	$objArr.Add($obj)
}
	
	

$headers.Add($primaryServer)
$headers.Add("File Name")
$headers.Add("Object Type")

for($j = 0; $j -lt $merges; $j++){
	$headers.Add($servers[$j])
}


$csvName = "SQLObjectsCompare." +(Get-Date -Format "yyyyMMddHHmmss")+".csv"

$csvHeaders = New-Object psobject
foreach($header in $headers)
{
 	Add-Member -InputObject $csvHeaders -MemberType noteproperty -Name $header -Value ""
}
$csvHeaders | Export-Csv ($csvPath+$csvName) -NoTypeInformation

$objArr | Export-Csv -append -Path ($csvPath+$csvName) -NoTypeInformation

start ($csvPath+$csvName)



