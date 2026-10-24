# Giu lai nhung gi R8 co the cat nham.
#
# BUILD_APK.bat da tat R8 (shrink=false). File nay chi con la luoi an toan khi
# ai do build release bang lenh khac: Flutter mac dinh LUON bat R8 o release. Cac lop
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

# Kieu Kotlin ma shared_preferences_android 2.5+ (va package:jni) tra theo
# ten qua JNI. R8 doi ten kotlin.coroutines.Continuation thi chu ky ham
# getAll(..., Continuation) khong con khop -> NoSuchMethodError luc mo app.
# Chep tu consumer-rules.pro cua shared_preferences_android 2.5.3.
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }

# Giu ten ngoai le de doc duoc bao loi tu ban da phat hanh
-keepattributes SourceFile,LineNumberTable,Signature,*Annotation*
