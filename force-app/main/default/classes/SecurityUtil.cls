public class SecurityUtil {

    public static Boolean canCreateFeedItem() {
        return Schema.sObjectType.FeedItem.isCreateable();
    }

    public static Boolean canCreateField(Schema.SObjectField f) {
        return f.getDescribe().isCreateable();
    }

    public static Boolean canReadField(Schema.SObjectField f) {
        return f.getDescribe().isAccessible();
    }

    public static Boolean canUpdateField(Schema.SObjectField f) {
        return f.getDescribe().isUpdateable();
    }

    public static Boolean canReadObject(Schema.SObjectType t) {
        return t.getDescribe().isAccessible();
    }
}
