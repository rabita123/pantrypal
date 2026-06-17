//
//  PantryPalWidgetBundle.swift
//  PantryPalWidget
//
//  Created by Sayra Tasmin Rabita on 6/13/26.
//

import WidgetKit
import SwiftUI

@main
struct PantryPalWidgetBundle: WidgetBundle {
    var body: some Widget {
        PantryPalWidget()
        PantryPalWidgetControl()
        PantryPalWidgetLiveActivity()
    }
}
