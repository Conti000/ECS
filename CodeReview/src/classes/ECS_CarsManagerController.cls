/**
 * Created by BRITENET on 01.02.2019.
 */

public with sharing class ECS_CarsManagerController {


    @AuraEnabled
    public static List<Product2> getCarsList(Product2 searchedCar) {
        return Database.query(generateQueryStringForSearchedCars(searchedCar));
    }

    @AuraEnabled
    public static String removeCar(Product2 carToDelete) {
        if (carToDelete != null) {
            try {
                delete carToDelete;
                return 'SUCCESS';
            } catch (DmlException e) {
                return 'ERROR';
            }
        } else {
            return 'ERROR';
        }
    }

    private static String generateQueryStringForSearchedCars(Product2 searchedCar) {
        String queryString;
        String conditionsSection = '';
        queryString = 'SELECT Id, Name, ECS_VinNumber__c, ECS_ProductionYear__c, ECS_Brand__c, ECS_Model__c, ECS_ImageID__c, ' +
                'ECS_EngineSize__c, ECS_FuelType__c, ECS_BodyStyle__c, ECS_Transmission__c, Description, ' +
                'ECS_BatteryCapacity__c' + ' FROM Product2 ';
        queryString += (String.isBlank(searchedCar.Name) &&
                String.isBlank(searchedCar.ECS_VinNumber__c) &&
                searchedCar.ECS_ProductionYear__c == null &&
                String.isBlank(searchedCar.ECS_Model__c)) ? '' : 'WHERE ';

        conditionsSection += String.isBlank(searchedCar.Name) ? '' : 'Name LIKE \'%' + searchedCar.Name + '%\'';
        conditionsSection += String.isNotBlank(conditionsSection) && String.isNotBlank(searchedCar.ECS_VinNumber__c) ? ' AND ' : '' ;
        conditionsSection += String.isBlank(searchedCar.ECS_VinNumber__c) ? '' : 'ECS_VinNumber__c LIKE \'%' + searchedCar.ECS_VinNumber__c + '%\'';
        conditionsSection += String.isNotBlank(conditionsSection) && searchedCar.ECS_ProductionYear__c != null ? ' AND ' : '' ;
        conditionsSection += searchedCar.ECS_ProductionYear__c == null ? '' : 'ECS_ProductionYear__c LIKE \'%' + searchedCar.ECS_ProductionYear__c + '%\'';
        conditionsSection += String.isNotBlank(conditionsSection) && String.isNotBlank(searchedCar.ECS_Model__c) ? ' AND ' : '' ;
        conditionsSection += String.isBlank(searchedCar.ECS_Model__c) ? '' : 'ECS_Model__c = \'' + searchedCar.ECS_Model__c + '\'';
//        conditionsSection += ' AND IsActive = true';


        queryString += conditionsSection == null ? '' : conditionsSection;
        system.debug('query string: ' + queryString);
        return queryString;
    }

    @AuraEnabled
    public static List<String> getImages(String carId) {
        List<ContentDocumentLink> linksList = [SELECT contentDocumentId FROM ContentDocumentLink WHERE linkedEntityId = :carId];
        List<String> documentsIds = new List<String>();
        for (ContentDocumentLink contentLink : linksList) {
            documentsIds.add(contentLink.contentDocumentId);
        }
        return documentsIds;
    }

    @AuraEnabled
    public static String setCarMainPictureId(String carId, String pictureId) {
        Product2 car = [SELECT id,name, ECS_ImageID__c FROM Product2 WHERE id = :carId];
        car.ECS_ImageID__c = pictureId;
        try {
            update car;
            return 'SUCCESS';
        } catch (DmlException e) {
            system.debug('error');
            return 'ERROR';
        }
    }
    @AuraEnabled
    public static String removeCarImage(String imageId) {
        system.debug('on removeCar Apex: picid to delete: ' + imageId);
        ContentDocument picture = [SELECT id FROM ContentDocument WHERE id = :imageId];
        try {
            delete picture;
            system.debug('on delete!!');
            return 'SUCCESS';
        } catch (DmlException e) {
            return 'ERROR';
        }
    }

    @AuraEnabled
    public static String getBaseUrlString() {
        return ECS_Setting__c.getInstance('ECS_InstanceUrl').ECS_InstanceUrl__c;
    }

    @AuraEnabled
    public static Boolean hasCurrentUserAdminProfile() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator'];
        return UserInfo.getProfileId() == profile.Id ? true : false;
    }

    @AuraEnabled
    public static String addCarToUserCart(Product2 car) {
        List<ECS_Wrappers.ECS_CartItem> cartItems;
        String currentLowestCarPrice = getCarCurrentLowestPrice(car.Id);

        if (Cache.Session.contains('local.Cart.cartItems')) {
            cartItems = (List<ECS_Wrappers.ECS_CartItem>) Cache.Session.get('local.Cart.cartItems');
            if (cartItems != null) {
                for (Integer ii = 0; ii < cartItems.size(); ii++) {
                    if (cartItems[ii].car.Id == car.Id) {
                        throw new AuraHandledException('Item already in cart');
                    }
                }
            }
        } else {
            cartItems = new List<ECS_Wrappers.ECS_CartItem>();
        }
        cartItems.add(new ECS_Wrappers.ECS_CartItem(car, null, currentLowestCarPrice));
        Cache.Session.put('local.Cart.cartItems', cartItems);
        return 'Success';
    }

    @AuraEnabled
    public static List<ECS_Wrappers.ECS_CartItem> getCustomerCartItems() {
        List<ECS_Wrappers.ECS_CartItem> cartItems;

        if (Cache.Session.contains('local.Cart.cartItems')) {
            cartItems = (List<ECS_Wrappers.ECS_CartItem>) Cache.Session.get('local.Cart.cartItems');
        } else {
            cartItems = new List<ECS_Wrappers.ECS_CartItem>();
        }
        return cartItems;
    }

    @AuraEnabled
    public static String deleteCustomerCartItem(List<String> listOfIds) {
        List<ECS_Wrappers.ECS_CartItem> cartItems;

        if (Cache.Session.contains('local.Cart.cartItems')) {
            cartItems = (List<ECS_Wrappers.ECS_CartItem>) Cache.Session.get('local.Cart.cartItems');
        } else {
            cartItems = new List<ECS_Wrappers.ECS_CartItem>();
        }

        if (cartItems != null) {
            for (Integer ii = 0; ii < cartItems.size(); ii++) {
                for (String carId : listOfIds) {
                    if (cartItems[ii].car.Id == carId) {
                        cartItems.remove(ii);
                    }
                }

            }

        }
        Cache.Session.put('local.Cart.cartItems', cartItems);
        return String.valueOf(cartItems.size());
    }

    @AuraEnabled
    public static String getCarStandardPrice(String carId) {
        String standardPriceBookId = [SELECT id, Name FROM Pricebook2 WHERE Name = 'Standard Price Book'][0].Id;
        List<PricebookEntry> carStandardPrices = [
                SELECT Id,UnitPrice
                FROM PricebookEntry
                WHERE Product2Id = :carId AND Pricebook2Id = :standardPriceBookId
        ];
        return String.valueOf(carStandardPrices[0].UnitPrice);
    }

    @AuraEnabled
    public static List<ECS_Wrappers.ECS_CartItem> getCarsWithStandardPrice(List<String> carIds) {
        List<Product2> cars = [
                SELECT Id,Name,ECS_Model__c,ECS_ProductionYear__c,ECS_VinNumber__c,ECS_ImageID__c
                FROM Product2
                WHERE Id IN :carIds
        ];
        List<ECS_Wrappers.ECS_CartItem> carItems = new List<ECS_Wrappers.ECS_CartItem>();
        for (Product2 car : cars) {
            String carStandardPrice = getCarStandardPrice(car.Id);
            carItems.add(new ECS_Wrappers.ECS_CartItem(car, carStandardPrice));
        }
        return carItems;
    }

    @AuraEnabled
    public static String getCarStandardPriceBookEntryId(String carId) {
        String standardPriceBookId = [SELECT id, Name FROM Pricebook2 WHERE Name = 'Standard Price Book'][0].Id;
        List<PricebookEntry> carStandardPrices = [SELECT Id,UnitPrice FROM PricebookEntry WHERE Product2Id = :carId AND Pricebook2Id = :standardPriceBookId];
        system.debug('selected prices: ' + carStandardPrices);
        return String.valueOf(carStandardPrices[0].Id);
    }

    @AuraEnabled
    public static String[] getCarLowestAndStandardPrice(String carId) {

        AggregateResult minAndMaxPriceResult = [
                SELECT MIN(UnitPrice)MinPrice, MAX(UnitPrice)MaxPrice
                FROM PricebookEntry
                WHERE Product2Id = :carId
                AND Pricebook2.ECS_currentlyActive__c = true
                AND Pricebook2.isActive = true
        ];
        List<String> minAndMaxPrice = new List<String>();
        minAndMaxPrice.add(String.valueOf(minAndMaxPriceResult.get('MinPrice')));
        minAndMaxPrice.add(String.valueOf(minAndMaxPriceResult.get('MaxPrice')));
        return minAndMaxPrice;
    }

    @AuraEnabled
    public static String getCarCurrentLowestPrice(String carId) {

        AggregateResult minPriceResult = [
                SELECT MIN(UnitPrice)MinPrice
                FROM PricebookEntry
                WHERE Product2Id = :carId
                AND Pricebook2.ECS_currentlyActive__c = true
                AND Pricebook2.isActive = true
        ];

        String minPrice = String.valueOf(minPriceResult.get('MinPrice'));
        return minPrice;
    }

    @AuraEnabled
    public static void setNewCarStandardPrice(String carId, Integer carPrice) {
        PricebookEntry listPrice = new PricebookEntry();
        listPrice.Pricebook2Id = getStandardPricebookId();
        listPrice.Product2Id = carId;
        listPrice.UnitPrice = carPrice;
        listPrice.IsActive = true;

        try {
            insert listPrice;
        } catch (DmlException e) {
            throw new AuraHandledException('Error creating PriceEntry');
        }

    }

    public static String getStandardPricebookId() {

        return [SELECT id, Name FROM Pricebook2 WHERE Name = 'Standard Price Book'][0].Id;
    }

    @AuraEnabled
    public static String proceedToCheckout() {

        List<ECS_Wrappers.ECS_CartItem> cartItems;


        if (Cache.Session.contains('local.Cart.cartItems')) {
            cartItems = (List<ECS_Wrappers.ECS_CartItem>) Cache.Session.get('local.Cart.cartItems');
        }



        String currentUserEmail = UserInfo.getUserEmail();
        Contact currentUserContact = [SELECT id FROM Contact WHERE Email = :currentUserEmail][0];
        Pricebook2 standardPriceBook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true];
        List<OrderItem> orderItems = new List<OrderItem>();
        Order order = new Order();


        order.AccountId = getCommunityCustomerAccountIdByEmail();
        order.Name = 'car(s) Order';
        order.EndDate = Date.today().addDays(30);
        order.Status = 'Draft';
        order.Pricebook2Id = standardPriceBook.Id;
        order.EffectiveDate = Date.today();

        try {
            insert order;
            system.debug('created: ' + order);
        } catch (System.DmlException e) {
            for (Integer i = 0; i < e.getNumDml(); i++) {
            }
            throw new AuraHandledException('Error creating order');
        }

        if (cartItems != null) {
            for (Integer ii = 0; ii < cartItems.size(); ii++) {
                OrderItem ordLineItem = new OrderItem();
                ordLineItem.Product2Id = cartItems[ii].car.Id;
                ordLineItem.OrderId = order.Id;
                ordLineItem.Quantity = 1;
                ordLineItem.UnitPrice = Integer.valueOf(getCarCurrentLowestPrice(cartItems[ii].car.Id));
                ordLineItem.PricebookEntryId = getCarStandardPriceBookEntryId(cartItems[ii].car.Id);
//                ordLineItem.ECS_StartingPrice__c = Integer.valueOf(getCarStandardPrice(cartItems[ii].car.Id));
                OrderItems.add(ordLineItem);

            }
        } else {
            throw new AuraHandledException('cart is empty');
        }
        try {
            deleteAllCustomerCartItems();
            insert orderItems;
        } catch (DmlException e) {
            throw new AuraHandledException('Error creating meetings');
        }


        Set<Id> carsIds = new Set<Id>();
        for (ECS_Wrappers.ECS_CartItem cartItem : cartItems) {
            carsIds.add(cartItem.car.Id);
        }

        List<Product2> listOfProducts = new List<Product2>([SELECT id, isActive FROM Product2 WHERE id IN :carsIds]);


        for (integer i = 0; i < listOfProducts.size(); i++) {
            listOfProducts[i].isActive = false;
        }

        try {
            update listOfProducts;
        } catch (DmlException e) {
            throw new AuraHandledException('Error updating cars');
        }

        return 'Success';

    }

    public static String getCommunityCustomerAccountIdByEmail() {
        String currentUserEmail = UserInfo.getUserEmail();
        if (currentUserEmail != null) {
            List<Contact> contacts = [SELECT AccountId FROM Contact WHERE Email = :currentUserEmail];
            return contacts[0].AccountId;
        } else {
            return 'Error';
        }

    }

    private static void deleteAllCustomerCartItems() {
        if (Cache.Session.contains('local.Cart.cartItems')) {
            Cache.Session.remove('local.Cart.cartItems');
        }
    }

    @AuraEnabled
    public static List<Order> getCustomerOrdersItems() {
        User currentUser = ECS_Utils.getCurrentUser();
        List<Order> orders = [
                SELECT Id, CreatedDate, OrderNumber, TotalAmount, (
                        SELECT Id, UnitPrice,
                                PricebookEntry.Product2.Name, PricebookEntry.Product2.ECS_Model__c,
                                PricebookEntry.Product2.ECS_ProductionYear__c, PricebookEntry.Product2.ECS_VinNumber__c,
                                PricebookEntry.Product2.ECS_ImageID__c
                        FROM OrderItems
                )
                FROM Order
                WHERE
                        OwnerId = :currentUser.Id

        ];
        return orders;
    }

    @AuraEnabled
    public static List<OrderItem> getCustomerPurchasedItems() {
        User currentUser = ECS_Utils.getCurrentUser();
        List<Order> listOfOrders = new List<Order>([
                SELECT id
                FROM Order
                WHERE OwnerId = :currentUser.Id
        ]);

        Set<Id> carsIds = new Set<Id>();
        for (Order order : listOfOrders) {
            carsIds.add(order.Id);
        }

        List<OrderItem> purchasedItems = new List<OrderItem>([
                SELECT id, OrderId, ECS_isReviewed__c, Order.CreatedDate, Product2.Id, Product2.Name,
                        Product2.ECS_Brand__c, Product2.ECS_Model__c, Product2.ECS_VinNumber__c,
                        Product2.ECS_ProductionYear__c, Product2.ECS_ImageID__c
                FROM OrderItem
                WHERE OrderId IN :carsIds
        ]);

        return purchasedItems;
    }

    @AuraEnabled
    public static List<ECS_Review__c> getProductReviewsById(String carId) {
        List<ECS_Review__c> reviews = [
                SELECT Id, ECS_Comment__c, ECS_Rating__c, CreatedBy.Username, CreatedDate
                FROM ECS_Review__c
                WHERE ECS_Product__c = :carId
                ORDER BY CreatedDate DESC
        ];
        if (reviews != null) {
            return reviews;
        } else {
            return new List<ECS_Review__c>();
        }
    }

    @AuraEnabled
    public static String deleteReviewById(String reviewId) {
        List<ECS_Review__c> review = [
                SELECT Id
                FROM ECS_Review__c
                WHERE Id = :reviewId
        ];
        if (review != null) {
            try {
                delete review;
                return 'Success';
            } catch (DmlException e) {
                return 'Error cannot delete review';
            }
        } else {
            return 'Error review not found';
        }
    }

    @AuraEnabled
    public static String setReviewAddedById(String orderItemId) {

        OrderItem orderItem = [SELECT id, ECS_isReviewed__c FROM OrderItem WHERE Id = :orderItemId LIMIT 1];
        orderItem.ECS_isReviewed__c = true;

        try {
            update orderItem;
        } catch (DmlException e) {
            return 'Error cannot update orderItem';
        }
        return 'SUCCESS';
    }

}