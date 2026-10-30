#!/usr/bin/env python3
"""Dependency-free deterministic Xcode project writer; generated project is committed."""
import hashlib
from pathlib import Path
import json
root = Path(__file__).resolve().parents[1]
objects = {}
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def q(value): return json.dumps(str(value))
def arr(values): return '(' + ', '.join(values) + (',' if values else '') + ')'
def obj(key, isa, **props):
    ident = uid(key)
    objects[ident] = {'isa': isa, **props}
    return ident
sources = ['Shared/AlarmDocument.swift', 'Shared/Connectivity.swift', 'Shared/Chime.swift', 'iPhone/PhoneApp.swift', 'Watch/WatchApp.swift']
refs = {p: obj(p, 'PBXFileReference', lastKnownFileType='sourcecode.swift', path=q(p), sourceTree='"<group>"') for p in sources}
resources = obj('resources', 'PBXFileReference', lastKnownFileType='folder', path='ChimeAssets', sourceTree='"<group>"')
products = {name: obj('product'+name, 'PBXFileReference', explicitFileType='wrapper.application', includeInIndex='0', path=q(name+'.app'), sourceTree='BUILT_PRODUCTS_DIR') for name in ['WatchAlarm', 'WatchAlarmWatch']}
productgroup = obj('products', 'PBXGroup', children=arr(list(products.values())), name='Products', sourceTree='"<group>"')
main = obj('group', 'PBXGroup', children=arr(list(refs.values())+[resources, productgroup]), sourceTree='"<group>"')

def configs(key, settings):
    result = []
    for name in ['Debug', 'Release']:
        opts = settings.copy()
        opts.update({'SWIFT_OPTIMIZATION_LEVEL': q('-Onone' if name == 'Debug' else '-O'), 'DEBUG_INFORMATION_FORMAT': q('dwarf' if name == 'Debug' else 'dwarf-with-dsym')})
        if name == 'Debug': opts['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        result.append(obj(key+name, 'XCBuildConfiguration', buildSettings=opts, name=name))
    return obj(key+'configlist', 'XCConfigurationList', buildConfigurations=arr(result), defaultConfigurationIsVisible='0', defaultConfigurationName='Release')
common = {'CLANG_ENABLE_MODULES':'YES','SWIFT_VERSION':'5.0','CODE_SIGN_STYLE':'Automatic','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0','GENERATE_INFOPLIST_FILE':'YES','PRODUCT_NAME':'"$(TARGET_NAME)"','INFOPLIST_KEY_CFBundleDisplayName':'"Watch Alarm"','SWIFT_EMIT_LOC_STRINGS':'YES','ENABLE_USER_SCRIPT_SANDBOXING':'YES'}
watchsettings = dict(common, SDKROOT='watchos', SUPPORTED_PLATFORMS='"watchos watchsimulator"', WATCHOS_DEPLOYMENT_TARGET='10.0', TARGETED_DEVICE_FAMILY='4', PRODUCT_BUNDLE_IDENTIFIER='jp.isobem.watchalarm.native20261030.watchkitapp', INFOPLIST_KEY_WKCompanionAppBundleIdentifier='jp.isobem.watchalarm.native20261030', INFOPLIST_KEY_WKApplication='YES', SKIP_INSTALL='YES')
phonesettings = dict(common, SDKROOT='iphoneos', SUPPORTED_PLATFORMS='"iphoneos iphonesimulator"', IPHONEOS_DEPLOYMENT_TARGET='17.0', TARGETED_DEVICE_FAMILY='1', PRODUCT_BUNDLE_IDENTIFIER='jp.isobem.watchalarm.native20261030', INFOPLIST_KEY_UILaunchScreen_Generation='YES', INFOPLIST_KEY_UIApplicationSceneManifest_Generation='YES', INFOPLIST_KEY_UISupportedInterfaceOrientations='UIInterfaceOrientationPortrait')
projectid=uid('project')
watchid=uid('targetWatchAlarmWatch')
proxy=obj('proxy','PBXContainerItemProxy',containerPortal=projectid,proxyType='1',remoteGlobalIDString=watchid,remoteInfo='WatchAlarmWatch')
dep=obj('dep','PBXTargetDependency',target=watchid,targetProxy=proxy)
for name, specific, settings in [('WatchAlarmWatch','Watch/WatchApp.swift',watchsettings),('WatchAlarm','iPhone/PhoneApp.swift',phonesettings)]:
    builds=[obj(name+p,'PBXBuildFile',fileRef=refs[p]) for p in sources if p.startswith('Shared/') or p==specific]
    sourcephase=obj(name+'sources','PBXSourcesBuildPhase',buildActionMask='2147483647',files=arr(builds),runOnlyForDeploymentPostprocessing='0')
    resbuild=obj(name+'res','PBXBuildFile',fileRef=resources)
    resphase=obj(name+'resources','PBXResourcesBuildPhase',buildActionMask='2147483647',files=arr([resbuild]),runOnlyForDeploymentPostprocessing='0')
    phases=[sourcephase,resphase]
    deps=[]
    if name=='WatchAlarm':
        embed=obj('embedfile','PBXBuildFile',fileRef=products['WatchAlarmWatch'],settings={'ATTRIBUTES':arr(['RemoveHeadersOnCopy'])})
        phases.append(obj('embedphase','PBXCopyFilesBuildPhase',buildActionMask='2147483647',dstPath='"$(CONTENTS_FOLDER_PATH)/Watch"',dstSubfolderSpec='16',files=arr([embed]),name='"Embed Watch Content"',runOnlyForDeploymentPostprocessing='0'))
        deps=[dep]
    obj('target'+name,'PBXNativeTarget',buildConfigurationList=configs(name,settings),buildPhases=arr(phases),buildRules='()',dependencies=arr(deps),name=name,productName=name,productReference=products[name],productType='"com.apple.product-type.application"')
obj('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'1600'},buildConfigurationList=configs('project',{'CLANG_ENABLE_MODULES':'YES'}),compatibilityVersion='"Xcode 14.0"',developmentRegion='ja',hasScannedForEncodings='0',knownRegions='(ja, en, Base)',mainGroup=main,productRefGroup=productgroup,projectDirPath='""',projectRoot='""',targets=arr([uid('targetWatchAlarm'),watchid]))
def render(value):
    if isinstance(value, dict): return '{\n' + '\n'.join(k+' = '+render(v)+';' for k,v in value.items()) + '\n}'
    return value
project=root/'WatchAlarm.xcodeproj'
project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+render({'archiveVersion':'1','classes':{},'objectVersion':'56','objects':objects,'rootObject':projectid})+'\n')
for name in products:
    ident=uid('target'+name)
    (project/'xcshareddata/xcschemes'/f'{name}.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:WatchAlarm.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:WatchAlarm.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated WatchAlarm.xcodeproj (iOS + single-target watchOS companion)')
