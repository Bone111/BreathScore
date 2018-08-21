//
//  Sample.swift
//  SeeScoreIOS
//
//  Created by James Sutton on 24/12/2015.
//  Copyright © 2015 Dolphin Computing Ltd. All rights reserved.
//
// Demonstrating use of a swift class

import Foundation

open class Sample : NSObject, SSUTempo
{
	public init(score : SSScore)
	{
		super.init()
		let pdata = SSPData.createPlay(from: score, tempo: self);
		for bar in (pdata?.bars)!
		{
			print("bar index %d duration:%dms", bar.index, bar.duration_ms)
			let part = bar.part(0)
			for note in (part?.notes)!
			{
				print("note %d", note.midiPitch)
			}
		}
	}
	
	// SSUTempo
	open func bpm() -> Int32
	{
		return 60
	}
	
	open func tempoScaling() -> Float
	{
		return 1.0
	}
}
