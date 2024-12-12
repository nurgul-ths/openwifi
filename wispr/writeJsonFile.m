%writeJsonFile - Writes a JSON file from struct jsonData
function writeJsonFile(jsonData, fName)
  jsonStr = jsonencode(jsonData, 'PrettyPrint', true);

  fid = fopen(fName, 'w');
  if fid == -1, error('Cannot open file: %s', fName); end
  fprintf(fid, '%s', jsonStr);
  fclose(fid);
end
