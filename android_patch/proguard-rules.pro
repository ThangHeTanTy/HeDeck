# Giu lai nhung gi R8 co the cat nham.
#
# Ngay ca khi khong dung --shrink, mot so cau hinh Gradle van bat R8. Cac lop
# duoi day duoc goi qua phan xa hoac qua cau noi Pigeon nen R8 khong nhin thay
# duong goi, rat de bi cat mat. Hau qua: ban release loi ma ban debug van chay.

# Flutter va cau noi plugin
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# shared_preferences: noi luu khoa thiet bi va bo cuc deck
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Pigeon sinh cac lop nay, goi qua phan xa
-keepclassmembers class ** {
    @io.flutter.plugin.common.** *;
}

# Giu ten ngoai le de doc duoc bao loi tu ban da phat hanh
-keepattributes SourceFile,LineNumberTable,Signature,*Annotation*
