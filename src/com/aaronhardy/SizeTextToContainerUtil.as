// Copyright (c) 2010 Aaron Hardy
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

package com.aaronhardy
{
	import flashx.textLayout.compose.IFlowComposer;
	import flashx.textLayout.container.ContainerController;
	import flashx.textLayout.edit.ElementRange;
	import flashx.textLayout.edit.SelectionState;
	import flashx.textLayout.elements.FlowLeafElement;
	import flashx.textLayout.elements.TextFlow;
	import flashx.textLayout.elements.TextRange;
	import flashx.textLayout.events.CompositionCompleteEvent;
	import flashx.textLayout.formats.Category;
	import flashx.textLayout.formats.ITextLayoutFormat;
	import flashx.textLayout.formats.TextLayoutFormat;
	import flashx.textLayout.operations.ApplyFormatOperation;
	import flashx.textLayout.property.Property;
	import flashx.textLayout.tlf_internal;
	use namespace tlf_internal;
	
	/**
	 * A utility to help set the optimal font size for a text flow so that the text is as large
	 * as possible without being cropped.
	 */
	public class SizeTextToContainerUtil
	{
		/**
		 * Sizes text in a text flow so that the text is as large as possible without being cropped.
		 *
		 * @param textFlow The text flow for which the font size should be changed.
		 * @param useIntegers Whether to use integer font size values rather than decimal values. 
		 *        When this is set to true, accuracyThreshold has no effect.
		 * @param minSize The minimim font size that should be allowed.
		 * @param maxSize The maximum font size that should be allowed.
		 * @param accuracyThreshold The threshold for accuracy. As the accuracy threshold
		 *        decreases, the font size will become more accurate but more processing will take
		 *        place. A large accuracy threshold will never result in text being cropped, but
		 *        the font size may end up smaller than the optimal size. An accuracy threshold
		 *        of .5 signifies that the resulting font size will be within .5 px of the optimal
		 *        font size. This has no effect when round is set to true.
		 * @return The resulting optimal font size.
		 */
		public static function sizeTextToContainer(textFlow:TextFlow,
												   useIntegers:Boolean=false,
												   minSize:uint=1,
												   maxSize:uint=720,
												   accuracyThreshold:Number=.3):Number
		{
			// We're going to be doing a lot of "test composing" in our attempts to find
			// a good font size. Lest other listeners do a bunch of processing each time they
			// hear COMPOSITION_COMPLETE events, we'll make sure we stop propagation of such
			// events during our tests.
			textFlow.addEventListener(CompositionCompleteEvent.COMPOSITION_COMPLETE,
				compositionCompleteHandler, false, int.MAX_VALUE);
			
			// For benchmarking:
//			var benchmarkStart:Number = new Date().time;
			
			// Get the textflow's font size before we start messing with it.
			// We just use this to get some hints.
			var originalSize:Number = getFontSize(textFlow);
			
			var lowHint:Number;
			var highHint:Number;
			
			if (!isNaN(originalSize))
			{
				// If we have an original size, we'll get some hints for our first couple
				// tests. This can dramatically reduce processing needed when this function
				// is called repeatedly when little has changed in the text. For example,
				// while the user is typing.
				if (useIntegers || accuracyThreshold == 0)
				{
					// If useIntegers is true, we can't give as tight of hints. Hints
					// really only improve performance when the current font size is already close
					// to the "optimal" font size. If useIntegers was set to true the last time
					// this function was called, then the current font size doesn't represent the
					// optimal font size as closely as it would if useIntegers was set to false the
					// last time this function was called. Because of this, we need to widen our
					// hints a bit. Remember, hints only really come in handy when this function is
					// called repeatedly when little has changed in the text, so it makes sense to
					// keep in mind what likely occurred the last time this function was called.
					lowHint = Math.floor(originalSize);
					highHint = Math.floor(originalSize + 1); // ensures min 1 difference
				}
				else
				{
					// If useIntegers is false, we can use +/- accuracyThreshold as our bounds.
					lowHint = originalSize - accuracyThreshold;
					highHint = originalSize + accuracyThreshold;
				}
			}
			
			var lowerBounds:Number = minSize;
			var upperBounds:Number = maxSize;
			var testSize:Number;
			var testResult:Boolean; // true means too small, false means too big.
			var bestSize:Number = minSize; // assumes that at least minSize will fit
			
			// Take up to 20 shots at whittling down font sizes until we get under the required
			// accuracy threshold.
			for (var i:uint; i < 20; i++)
			{
				// Try using our hints if possible. Otherwise, go with the average between
				// the lower and upper bounds.
				if (i == 0 && !isNaN(lowHint) && lowHint > lowerBounds &&
					lowHint < upperBounds)
				{
					testSize = lowHint;
				}
				else if (i == 1 && !isNaN(highHint) && highHint > lowerBounds &&
					highHint < upperBounds)
				{
					testSize = highHint;
				}
				else
				{
					testSize = (lowerBounds + upperBounds) / 2;
				}
			
				// Attempt the test font size.
				testResult = attemptSize(textFlow, testSize);
				
				if (testResult) // text too small (or, possibly, technically, just right)
				{
					lowerBounds = testSize;
				
					// Store this test size if it's more accurate than the previous size
					// we tested.
					if (testSize > bestSize)
					{
						bestSize = testSize;
					}
				}
				else // text too large
				{
					upperBounds = testSize;
				}
				
				// If useIntegers is set to true, accuracyThreshold doesn't have any effect.
				// Here's an example to explain the reason:
				// bestSize is 8.75
				// upperBounds is 9.25
				// accuracyThreshold is .5
				// In this case, we would technically be within the threshold, but bestSize would
				// later be floored to 8. But what if it could have legitimately passed a
				// a test for 9 and floored to 9? For this reason we don't use the threshold
				// and take a different approach instead.
				if (useIntegers)
				{
					// If the floor of best size is the same as the floor of upperBounds, then
					// we really can't obtain a better bestSize when taking flooring into account.
					if (Math.floor(bestSize) == Math.floor(upperBounds))
					{
						break;
					}
				}
				else
				{
					// If we're within the accuracy threshold we'll call it a day.
					if (upperBounds - bestSize <= accuracyThreshold)
					{
						break;
					}
				}
			}
			
			// Floor the font size if requested. We can't round because we don't want the
			// possibility of text cropping.
			if (useIntegers)
			{
				bestSize = Math.floor(bestSize);
			}
			
			// Make sure the text flow is set to the best size. If the last test we did WAS
			// our best size, we don't need to re-set the font size.
			if (bestSize != testSize)
			{
				setFontSize(textFlow, bestSize);
			}
			
			textFlow.flowComposer.updateAllControllers();
			
			// For benchmarking:
//			trace("Best size: " + bestSize,
//				"Processing time: " + (new Date().time - benchmarkStart) + 'ms',
//				"Loops: " + i);
			
			textFlow.removeEventListener(CompositionCompleteEvent.COMPOSITION_COMPLETE,
				compositionCompleteHandler);
			
			return bestSize;
		}
		
		/**
		 * Sets all text in the text flow to a specified size and determines if the text is larger
		 * or smaller than all the containers.
		 *
		 * @return True if the text fits within the containers. False if the text does not fit
		 * within the containers.
		 */
		private static function attemptSize(textFlow:TextFlow, size:Number):Boolean
		{
			if (setFontSize(textFlow, size))
			{
				var flowComposer:IFlowComposer = textFlow.flowComposer;
				
				// Compose() instead of a full updateAllControllers() for speed.
				flowComposer.compose();
				
				// Probably faster than the findControllerIndexAtPosition() approach.
				var lastController:ContainerController = ContainerController(
					flowComposer.getControllerAt(flowComposer.numControllers - 1));
				return lastController.absoluteStart + lastController.textLength >=
					textFlow.textLength;
			}
			else
			{
				throw new Error('Error sizing text in text flow.');
			}
		}
		
		/**
		 * Sets the font size for all text in the text flow.
		 *
		 * @return Whether the font size was successfully set.
		 */
		private static function setFontSize(textFlow:TextFlow, size:Number):Boolean
		{
			var format:TextLayoutFormat = new TextLayoutFormat();
			format.fontSize = size;
			var selectionState:SelectionState = new SelectionState(textFlow, 0, textFlow.textLength - 1);
			var formatOperation:ApplyFormatOperation = new ApplyFormatOperation(selectionState,
				format, null, null);
			return formatOperation.doOperation();
		}
		
		/**
		 * Stops immediate propagation of CompositionCompleteEvents. This is so listeners aren't
		 * processing the event many times while we attempt to find an adequate font size.
		 */
		private static function compositionCompleteHandler(event:CompositionCompleteEvent):void
		{
			event.stopImmediatePropagation();
		}
		
		/**
		 * Retrieves the current common font size for the text flow.
		 */
		private static function getFontSize(textFlow:TextFlow):Number
		{
			var fullRange:TextRange = new TextRange(textFlow, 0, textFlow.textLength - 1);
			return getCommonCharacterFormatFromRange(fullRange).fontSize;
		}
		
		/**
		 * @see flashx.textLayout.edit.SelectionManager#getCommonCharacterFormatFromRange();
		 * @see http://forums.adobe.com/thread/462061
		 * Does the same as the original SelectionManager function except works around a bug.
		 * In SelectionManager's, if nothing is selected in the textflow, the font size
		 * of the first leaf is returned, even if there are multiple font sizes in the textflow.
		 * In our case, we want it to return a font size of undefined.
		 */
		private static function getCommonCharacterFormatFromRange(range:TextRange):ITextLayoutFormat
		{
			if (!range)
				return null;
		
			var selRange:ElementRange = ElementRange.createElementRange(
				range.textFlow, range.absoluteStart, range.absoluteEnd);
			
			var leaf:FlowLeafElement = selRange.firstLeaf;
			var attr:TextLayoutFormat = new TextLayoutFormat(leaf.computedFormat);
			
			for (;;)
			{
				if (leaf == selRange.lastLeaf)
					break;
				leaf = leaf.getNextLeaf();
				attr.removeClashing(leaf.computedFormat);
			}
			
			return Property.extractInCategory(TextLayoutFormat, TextLayoutFormat.description, attr,
				Category.CHARACTER) as ITextLayoutFormat;
		}
	}
}