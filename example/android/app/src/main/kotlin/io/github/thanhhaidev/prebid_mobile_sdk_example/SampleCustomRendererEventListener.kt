/*
 *    Copyright 2018-2021 Prebid.org, Inc.
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

// Ported unchanged from prebid-mobile-android Example/PrebidInternalTestApp
// (renderingtestapp/utils), only the package differs.
package io.github.thanhhaidev.prebid_mobile_sdk_example

import org.prebid.mobile.api.rendering.pluginrenderer.PluginEventListener

interface SampleCustomRendererEventListener : PluginEventListener {
    override fun getPluginRendererName(): String = SampleCustomRenderer.SAMPLE_PLUGIN_RENDERER_NAME
    fun onImpression()
}