/* IF TABLES EXIST, DROP THEM */
IF OBJECT_ID('dbo.ShelfRestock') IS NOT NULL
BEGIN
drop table dbo.ShelfRestock
END

IF OBJECT_ID('dbo.Shelf') IS NOT NULL
BEGIN
drop table dbo.Shelf
END

IF OBJECT_ID('dbo.InventoryOrder') IS NOT NULL
BEGIN
drop table dbo.InventoryOrder
END

IF OBJECT_ID('dbo.Inventory') IS NOT NULL
BEGIN
drop table dbo.Inventory
END

IF OBJECT_ID('dbo.Basket') IS NOT NULL
BEGIN
drop table dbo.Basket
END

IF OBJECT_ID('dbo.Item') IS NOT NULL
BEGIN
drop table dbo.Item
END

IF OBJECT_ID('dbo.Supplier') IS NOT NULL
BEGIN
drop table dbo.Supplier
END

IF OBJECT_ID('dbo.Purchase') IS NOT NULL
BEGIN
drop table dbo.Purchase
END

IF OBJECT_ID('dbo.Customer') IS NOT NULL
BEGIN
drop table dbo.Customer
END

go


/* CREATE TABLES */

-- Creating the Customer table
create table Customer (
	-- Columns
	CustomerID int identity,
	FirstName varchar(20),
	LastName varchar(20),
	EmailAddress varchar(50) not null,
	PhoneNumber varchar(20) not null,
	Gender varchar(1),
	DOB datetime,
	MaritalStatus varchar(10),
	SecondaryOf int,
	-- Constraints
	constraint PK_Customer primary key (CustomerID),
	constraint U1_Customer unique(EmailAddress),
	constraint U2_Customer unique(PhoneNumber)
)

-- Creating the Purchase table
create table Purchase (
	-- Columns
	PurchaseID int identity,
	CustomerID int not null,
	StartTime datetime not null default GetDate(),
	EndTime datetime,
	CashierType varchar(1) not null,
	-- Constraints
	constraint PK_Purchase primary key (PurchaseID),
	constraint FK1_Purchase foreign key (CustomerID) references Customer(CustomerID)
)

-- Creating the Supplier table
create table Supplier (
	-- Columns
	SupplierID int identity,
	Name varchar(50) not null,
	-- Constraints
	constraint PK_Supplier primary key (SupplierID),
	constraint U1_Supplier unique(Name)
)

-- Creating the Item table
create table Item (
	-- Columns
	ItemID int identity,
	ItemName varchar(20) not null,
	SupplierID int not null,
	-- Constraints
	constraint PK_Item primary key (ItemID),
	constraint U1_Item unique(ItemName),
	constraint FK1_Item foreign key (SupplierID) references Supplier(SupplierID)
)

-- Creating the Basket table
create table Basket (
	-- Columns
	BasketID int identity,
	PurchaseID int not null,
	ItemID int not null,
	Quantity int not null,
	-- Constraints
	constraint PK_Basket primary key (BasketID),
	constraint U1_Basket unique(PurchaseID, ItemID),
	constraint FK1_Basket foreign key (PurchaseID) references Purchase(PurchaseID),
	constraint FK2_Basket foreign key (ItemID) references Item(ItemID)
)

-- Creating the Inventory table
create table Inventory (
	-- Columns
	InventoryID int identity,
	Location varchar(10) not null,
	ItemID int not null,
	Quantity int not null,
	-- Constraints
	constraint PK_Inventory primary key (InventoryID),
	constraint U1_Inventory unique(Location, ItemID),
	constraint FK1_Inventory foreign key (ItemID) references Item(ItemID)
)

-- Creating the InventoryOrder table
create table InventoryOrder (
	-- Columns
	OrderID int identity,
	ItemID int not null,
	Quantity int not null,
	Date datetime not null default GetDate(),
	-- Constraints
	constraint PK_InventoryOrder primary key (OrderID),
	constraint FK1_InventoryOrder foreign key (ItemID) references Item(ItemID)
)

-- Creating the Shelf table
create table Shelf (
	-- Columns
	ShelfID int identity,
	Aisle varchar(2) not null,
	Height int not null,
	ItemID int,
	Quantity int,
	-- Constraints
	constraint PK_Shelf primary key (ShelfID),
	constraint FK1_Shelf foreign key (ItemID) references Item(ItemID),
	constraint U1_Shelft unique(Aisle, Height)
)

-- Creating the ShelfRestock table
create table ShelfRestock (
	-- Columns
	RestockID int identity,
	ShelfID int not null,
	ItemID int not null,
	Quantity int not null,
	Date datetime not null default GetDate(),
	-- Constraints
	constraint PK_ShelfRestock primary key (RestockID),
	constraint FK1_ShelfRestock foreign key (ShelfID) references Shelf(ShelfID),
	constraint FK2_ShelfRestock foreign key (ItemID) references Item(ItemID)
)

go


/* IF PROCEDURES EXIST, DROP THEM */
IF OBJECT_ID('dbo.OrderInventory') IS NOT NULL
BEGIN
drop procedure dbo.OrderInventory
END

IF OBJECT_ID('dbo.RestockShelf') IS NOT NULL
BEGIN
drop procedure dbo.RestockShelf
END

IF OBJECT_ID('dbo.InitializePurchase') IS NOT NULL
BEGIN
drop procedure dbo.InitializePurchase
END

IF OBJECT_ID('dbo.CreateBasket') IS NOT NULL
BEGIN
drop procedure dbo.CreateBasket
END

IF OBJECT_ID('dbo.FinalizePurchase') IS NOT NULL
BEGIN
drop procedure dbo.FinalizePurchase
END

go

/* CREATE PROCEDURES */
-- Creating procedure to record Inventory Order
create procedure OrderInventory(@itemName varchar(20), @quantity int, @location varchar(10)) as
begin
	-- get ItemID for Foreign Key from Item table
	declare @ItemID int
	select @ItemID = ItemID from Item where ItemName = @itemName;

	-- Start a transaction because Order and Inventory need to be updated simultaneously
	begin tran;
		insert into InventoryOrder (ItemID, Quantity) values (@ItemID, @quantity);
		insert into Inventory (Location, ItemID, Quantity) values (@location, @ItemID, @quantity);
	commit tran
end
go

-- Creating procedure to record Shelf Restock
create procedure RestockShelf(@itemName varchar(20), @quantity int, @aisle varchar(2), @height int) as
begin
	-- get ItemID from Item table and ShelfID from Shelf table for Foreign Keys
	declare @ItemID int
	declare @ShelfID int
	select @ItemID = ItemID from Item where ItemName = @itemName;
	select @ShelfID = ShelfID from Shelf where Aisle = @aisle and Height = @height;
	
	-- The store wants to use up smallest inventories, so we need to get the associated InventoryID to update later
	declare @InventoryID int
	select top 1 @InventoryID = InventoryID from Inventory where ItemID = @ItemID order by Quantity asc

	-- Start a transaction because Restock, Shelf, and Inventory all need to be updated simultaneously
	begin tran;
		insert into ShelfRestock (ShelfID, ItemID, Quantity) values (@ShelfID, @ItemID, @quantity);
		-- If the item being restocked was already on that shelf, only update the quantity
		-- If there was a different item on that shelf, update the itemID and the quantity
		if exists (select * from Shelf where ShelfID = @ShelfID and ItemID = @ItemID)
			begin
			update Shelf set Quantity = Quantity + @quantity where ShelfID = @ShelfID and ItemID = @ItemID;
			end
		else
			begin
			update Shelf set ItemID = @ItemID, Quantity = @quantity where ShelfID = @ShelfID;
			end
		-- We need to update the Inventory table as items are moved from storage to the floor
		update Inventory set Quantity = Quantity - @quantity where InventoryID = @InventoryID;
		-- If an inventory reaches 0, additional restock quantity should be entered separately
	commit tran
end
go

-- Create procedure to initialize a purchase at an automate register
-- Purchases begin when a customer enters their phone number at the register to verify membership
-- In practice, cash register would automatically pass @cashierType, but here we need to manually input it
create procedure InitializePurchase (@phoneNumber varchar(20), @cashierType varchar(1))
as
begin
	-- get CustomerID from Customer table for Foreign Key
	declare @CustomerID int
	select @CustomerID = CustomerID from Customer where PhoneNumber = @phoneNumber;

	insert into Purchase (CustomerID, CashierType) values (@CustomerID, @cashierType);
	
	-- Return newly created PurchaseID for Creating Basket
	return @@identity
end
go

-- Creating procedure to create Basket as Items are scanned
-- @PurchaseID should always be @@identity, which was returned by InitializePurchase
create procedure CreateBasket(@itemName varchar(20), @PurchaseID int) as
begin
	-- get ItemID from Item table for Foreign Key
	declare @ItemID int
	select @ItemID = ItemID from Item where ItemName = @itemName;

	-- If the item was already in the basket, only update the quantity
	-- If the item is being added for the first time, insert the itemID and purchaseID
	if exists (select * from Basket where PurchaseID = @PurchaseID and ItemID = @ItemID)
		begin
		update Basket set Quantity = Quantity + 1 where PurchaseID = @PurchaseID and ItemID = @ItemID;
		end
	else
		begin
		insert into Basket (PurchaseID, ItemID, Quantity) values (@PurchaseID, @ItemID, 1);
		end
end
go

-- Creating procedure to finalize Purchase
-- @PurchaseID should always be @@identity, which was returned by InitializePurchase
create procedure FinalizePurchase(@PurchaseID int) as
begin
	update Purchase set EndTime = GetDate() where PurchaseID = @PurchaseID
end
go

--SELECT * FROM Shelf
--insert into Shelf (Aisle,Height,ItemID,Quantity) values('A1', 1,1,5)
--update Shelf set Quantity = Quantity + 5 where ShelfID = 1 and ItemID = 1;
--insert into Supplier (Name) values ('testing')
--insert into item (ItemName, SupplierID) values ('testitem', 1)

--exec OrderInventory '',,'';
--exec RestockShelf '',,'',;
--exec InitializePurchase '','';
--exec CreateBasket '',@@identity;
--exec FinalizePurchase @@identity;

--insert into Supplier (Name) values ('');
--insert into Item (ItemName, SupplierID) values ('', (select SupplierID from Supplier where Name = ''));
--insert into Customer (EmailAddress, PhoneNumber) values ('','');
--insert into Shelf (Aisle, Height) values('',);

-- Load Suppliers into Supplier table
insert into Supplier (Name) values ('Turducken Co');
insert into Supplier (Name) values ('Stuffs R Us');
insert into Supplier (Name) values ('All That Jazz Inc.');
insert into Supplier (Name) values ('Cramazon.com');
insert into Supplier (Name) values ('BunchOStuff Corp');

-- Load Items into Item table
insert into Item (ItemName, SupplierID) values ('Apple', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Orange', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Smart Watch', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Laptop', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Camping Tent', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Socks', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Shirt', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Granola Bar', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Toothpaste', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Spoon', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Micromave', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Notebook', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Baseball', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Scissors', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Fan', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Lamp', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Light Bulb', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Jacket', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Pizza', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Cupcake', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Ice Cream', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Carrot', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Broccoli', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Suit Case', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Umbrella', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Pool Noodle', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Camera', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Book', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Lawn Chair', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Video Game', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Tape', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Stapler', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Armband', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Pull Up Bar', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Bench', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Treadmill', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Picture', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Frame', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Doorknob', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Screw', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));
insert into Item (ItemName, SupplierID) values ('Hammer', (select SupplierID from Supplier where Name = 'Turducken Co'));
insert into Item (ItemName, SupplierID) values ('Wall Hook', (select SupplierID from Supplier where Name = 'Stuffs R Us'));
insert into Item (ItemName, SupplierID) values ('Trading Card Pack', (select SupplierID from Supplier where Name = 'All That Jazz Inc.'));
insert into Item (ItemName, SupplierID) values ('Multivitamin', (select SupplierID from Supplier where Name = 'Cramazon.com'));
insert into Item (ItemName, SupplierID) values ('Athletic Tape', (select SupplierID from Supplier where Name = 'BunchOStuff Corp'));

-- Load Customers into Customer table
insert into Customer (EmailAddress, PhoneNumber) values ('hoogla@boogla.net','234-567-8901');
insert into Customer (EmailAddress, PhoneNumber) values ('jane@doe.com','234-567-8902');
insert into Customer (EmailAddress, PhoneNumber) values ('who@dat.org','234-567-8903');
insert into Customer (EmailAddress, PhoneNumber) values ('whats@up.com','234-567-8904');
insert into Customer (EmailAddress, PhoneNumber) values ('ka@pow.net','234-567-8905');
insert into Customer (EmailAddress, PhoneNumber) values ('splish@splash.org','234-567-8906');
insert into Customer (EmailAddress, PhoneNumber) values ('some@dude.com','234-567-8907');
insert into Customer (EmailAddress, PhoneNumber) values ('some@dudette.com','234-567-8908');
