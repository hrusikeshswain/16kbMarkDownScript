# 16kbMarkDownScript
# 16KB Alignment Guide for React Native

## Overview

16KB alignment is a requirement for native libraries (`.so` files) in Android APKs, especially important for devices running Android 15+ which use 16KB page sizes. Misaligned libraries can cause performance issues, crashes, or app rejection from Google Play Store.

## What is 16KB Alignment?

16KB alignment means that native library files in the APK must start at memory offsets that are multiples of 16,384 bytes (16KB). This ensures optimal memory mapping and performance on modern Android devices.

## Why It Matters

- **Android 15+ Requirement**: Devices with 16KB page sizes require proper alignment
- **Performance**: Properly aligned libraries load faster and use memory more efficiently
- **Google Play Store**: Apps with misaligned libraries may be rejected
- **Crash Prevention**: Misaligned libraries can cause runtime crashes

## Checking Alignment

### Using the Analysis Script

We have a script to check alignment in your APK:

```bash
./scripts/analyze_apk.sh android/app/build/outputs/apk/release/app-release.apk
```

This will show:
- Library name
- React Native package name (if applicable)
- 16KB alignment status (YES/NO)

### Using zipalign Directly

```bash
# Check alignment
zipalign -c -v 4 your-app.apk

# Output format:
# 31014912 lib/arm64-v8a/libname.so (OK)      # Aligned
# 31014912 lib/arm64-v8a/libname.so (FAILED)  # Misaligned
```

### Using Android Studio

1. Open Android Studio
2. Build > Analyze APK
3. Select your APK file
4. Navigate to `lib/` folder
5. Check alignment status for each `.so` file

## Fixing Alignment Issues

### Method 1: Use zipalign (Recommended)

```bash
# Align your APK
zipalign -v -p 4 unaligned.apk aligned.apk

# Verify alignment
zipalign -c -v 4 aligned.apk

# Sign the aligned APK (if needed)
apksigner sign --ks your-keystore.jks aligned.apk
```

### Method 2: Configure Gradle Build

Ensure your `android/app/build.gradle.kts` or `build.gradle` includes proper alignment:

```kotlin
android {
    // ... other config
    
    buildTypes {
        release {
            // Ensure zipalign is enabled
            isMinifyEnabled = true
            // ... other config
        }
    }
}
```

The Android Gradle Plugin automatically aligns APKs during the build process for release builds.

### Method 3: Update React Native

Newer versions of React Native handle alignment automatically. Update to ensure proper alignment:

```bash
# Check your React Native version
npm list react-native

# Update React Native
npm install react-native@latest
# or
yarn add react-native@latest
```

## React Native Version Compatibility

### React Native 0.74.3+ (Current)
- ✅ Automatic 16KB alignment in release builds
- ✅ Proper zipalign configuration in Gradle
- ✅ Compatible with Android Gradle Plugin 8.0+

### React Native 0.73.x
- ✅ Automatic alignment in most cases
- ⚠️ May require manual zipalign for some libraries

### React Native 0.72.x and earlier
- ⚠️ May require manual alignment
- ⚠️ Check alignment after build
- ✅ Can be fixed with post-build zipalign

## Ensuring Alignment in Your Build

### 1. Update Android Gradle Plugin

In `android/build.gradle.kts`:

```kotlin
buildscript {
    ext {
        buildToolsVersion = "34.0.0"  // Use latest
        minSdkVersion = 21
        compileSdkVersion = 34
        targetSdkVersion = 34
    }
    
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.0")  // Use 8.0+
    }
}
```

### 2. Configure Build Types

In `android/app/build.gradle.kts`:

```kotlin
android {
    buildTypes {
        release {
            // These ensure proper alignment
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    // Ensure proper signing
    signingConfigs {
        release {
            // Your signing config
        }
    }
}
```

### 3. Post-Build Verification Script

Add to `package.json`:

```json
{
  "scripts": {
    "android:build:release": "cd android && ./gradlew assembleRelease",
    "android:verify:alignment": "./scripts/analyze_apk.sh android/app/build/outputs/apk/release/app-release.apk",
    "android:align:apk": "zipalign -v -p 4 android/app/build/outputs/apk/release/app-release.apk android/app/build/outputs/apk/release/app-release-aligned.apk"
  }
}
```

## Common Issues and Solutions

### Issue: All libraries show as misaligned

**Solution:**
1. Ensure you're checking a release build (debug builds may not be aligned)
2. Verify Android Gradle Plugin version (8.0+)
3. Rebuild the APK: `./gradlew clean assembleRelease`

### Issue: Some React Native libraries are misaligned

**Solution:**
1. Update React Native to latest version
2. Update all React Native dependencies:
   ```bash
   npm update
   # or
   yarn upgrade
   ```
3. Clear build cache:
   ```bash
   cd android
   ./gradlew clean
   cd ..
   ```

### Issue: Third-party native libraries misaligned

**Solution:**
1. Check if the library has an update
2. Report the issue to the library maintainer
3. Use post-build zipalign as a workaround

### Issue: zipalign not found

**Solution:**
1. Install Android SDK Build-Tools:
   ```bash
   # Via Android Studio: SDK Manager > SDK Tools > Android SDK Build-Tools
   # Or via command line:
   sdkmanager "build-tools;34.0.0"
   ```
2. Set ANDROID_HOME:
   ```bash
   export ANDROID_HOME=$HOME/Library/Android/sdk  # macOS
   export ANDROID_HOME=$HOME/Android/Sdk          # Linux
   export PATH=$PATH:$ANDROID_HOME/build-tools/34.0.0
   ```

## React Native Package-Specific Notes

### react-native-screens
- ✅ Properly aligned in versions 3.27.0+
- ⚠️ Check alignment for older versions

### react-native-reanimated
- ✅ Properly aligned in versions 3.6.0+
- ⚠️ May require manual alignment in older versions

### react-native-webview
- ✅ Generally well-aligned
- ✅ Compatible with 16KB alignment

### hermes-engine
- ✅ Automatically aligned by React Native build system
- ✅ No manual intervention needed

### react-native-pdf
- ⚠️ Check alignment after updates
- ✅ Usually aligned in recent versions

## Best Practices

1. **Always check alignment before release**
   ```bash
   ./scripts/analyze_apk.sh your-release.apk
   ```

2. **Use release builds for testing alignment**
   - Debug builds may not be properly aligned
   - Always verify release APKs

3. **Keep dependencies updated**
   - Newer versions often fix alignment issues
   - Regular updates ensure compatibility

4. **Automate alignment checks**
   - Add to CI/CD pipeline
   - Fail builds if misaligned libraries found

5. **Document alignment status**
   - Keep track of which libraries need attention
   - Update this doc when issues are found

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Check APK Alignment
  run: |
    ./scripts/analyze_apk.sh android/app/build/outputs/apk/release/app-release.apk
    # Fail if any library is misaligned
    if ./scripts/analyze_apk.sh android/app/build/outputs/apk/release/app-release.apk | grep -q "NO"; then
      echo "❌ Misaligned libraries found!"
      exit 1
    fi
```

### GitLab CI Example

```yaml
check_alignment:
  script:
    - ./scripts/analyze_apk.sh android/app/build/outputs/apk/release/app-release.apk
    - |
      if ./scripts/analyze_apk.sh android/app/build/outputs/apk/release/app-release.apk | grep -q "NO"; then
        echo "❌ Misaligned libraries found!"
        exit 1
      fi
```

## Troubleshooting

### Script shows "zipalign not found"

1. Check if Android SDK is installed
2. Verify zipalign location:
   ```bash
   find ~/Library/Android/sdk -name zipalign
   ```
3. The script should auto-detect, but you can set ANDROID_HOME manually

### Script shows all libraries as "NO"

1. Verify you're checking a release build
2. Check if zipalign is working:
   ```bash
   zipalign -c -v 4 your-apk.apk | head -10
   ```
3. Rebuild the APK with clean:
   ```bash
   cd android && ./gradlew clean assembleRelease
   ```

### Alignment works locally but fails in CI

1. Ensure CI has Android SDK installed
2. Set ANDROID_HOME in CI environment
3. Install build-tools in CI:
   ```bash
   sdkmanager "build-tools;34.0.0"
   ```

## References

- [Android 16KB Page Size](https://source.android.com/docs/core/architecture/kernel/16kb-page-size)
- [zipalign Documentation](https://developer.android.com/studio/command-line/zipalign)
- [React Native Android Build](https://reactnative.dev/docs/signed-apk-android)
- [Google Play Store Requirements](https://support.google.com/googleplay/android-developer/answer/11926878)

## Version History

- **2024-12-09**: Initial documentation created
- Document alignment requirements and solutions for React Native apps

---

**Note**: Always verify alignment before submitting to Google Play Store, especially for Android 15+ target SDK.

