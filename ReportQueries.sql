-- REPORT 1
select p.CashierType, avg(datediff(second, p.StartTime, p.EndTime)) as AvgTime
from Purchase p
join Basket b on p.PurchaseID = b.PurchaseID
join ItemsPerPurchase i on i.PurchaseID = p.PurchaseID
where i.TotalQuantity >= 10
group by p.CashierType

-- REPORT 2
select s.Aisle, count(s.Aisle) as Occurences
from Shelf s
join Basket b on s.ItemID = b.ItemID
join ItemsPerPurchase i on b.PurchaseID = i.PurchaseID
where i.TotalQuantity >=10
group by s.Aisle
order by Occurences desc

-- REPORT 3
select top 10 i.ItemName, q.TotalPurchased from
Item i
join (select b.ItemID, sum(b.Quantity) as TotalPurchased from
Basket b
join Purchase p on p.PurchaseID = b.PurchaseID
where p.EndTime >= DATEADD(month, -1, getdate())
group by b.ItemID) q on i.ItemID = q.ItemID
order by q.TotalPurchased desc

-- REPORT 4
select c.CustomerID, c.EmailAddress, c.PhoneNumber, p.MonthNumber, p.NumofPurchases from
Customer c
join (select CustomerID, month(EndTime) as MonthNumber, count(PurchaseID) as NumofPurchases from
Purchase
group by CustomerID, month(EndTime)) p on p.CustomerID = c.CustomerID

-- REPORT 5
select i.ItemName, r.TimesRestocked, o.TimesOrdered from Item i
left join (select ItemID, count(RestockID) as TimesRestocked from
ShelfRestock
where Date >= DATEADD(month, -3, getdate())
group by ItemID) r on i.ItemID = r.ItemID
left join (select ItemID, count(OrderID) as TimesOrdered from
InventoryOrder
where Date >= DATEADD(month, -3, getdate())
group by ItemID) o on i.ItemID = o.ItemID