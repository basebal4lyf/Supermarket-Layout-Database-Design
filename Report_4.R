require(RODBC)
myconn <- odbcConnect("VidCast64")
sqlSelectStatement <- "select c.CustomerID, c.EmailAddress, c.PhoneNumber, p.MonthNumber, p.NumofPurchases from
Customer c
join (select CustomerID, month(EndTime) as MonthNumber, count(PurchaseID) as NumofPurchases from
Purchase
group by CustomerID, month(EndTime)) p on p.CustomerID = c.CustomerID"
Report4 <- sqlQuery(myconn, sqlSelectStatement)
odbcCloseAll()
print(Report4)