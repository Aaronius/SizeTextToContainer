package
{
	import com.aaronhardy.SizeTextToContainerUtil;
	import com.adobe.viewsource.ViewSource;
	
	import flash.display.Sprite;
	import flash.display.StageScaleMode;
	
	import flashx.textLayout.container.ContainerController;
	import flashx.textLayout.container.ScrollPolicy;
	import flashx.textLayout.edit.EditManager;
	import flashx.textLayout.elements.TextFlow;
	import flashx.textLayout.events.FlowOperationEvent;
	
	import org.osmf.display.ScaleMode;

	[SWF(backgroundColor='#cccccc', width='150', height='100')]
	public class Main extends Sprite
	{
		protected var textFlow:TextFlow;
		
		public function Main()
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			ViewSource.addMenuItem(this, "srcview/index.html"); 
			
			const textWidth:Number = 150;
			const textHeight:Number = 100;
			
			graphics.clear();
			graphics.beginFill(0xffffff);
			graphics.drawRect(0, 0, textWidth, textHeight);
			graphics.endFill();
			
			textFlow = new TextFlow();
			
			var textContainer:Sprite = new Sprite();
			addChild(textContainer);
			
			var controller:ContainerController = new ContainerController(
					textContainer, textWidth, textHeight);
			controller.verticalScrollPolicy = controller.horizontalScrollPolicy =
					ScrollPolicy.OFF;
			textFlow.flowComposer.addController(controller);
			textFlow.flowComposer.updateAllControllers();
			textFlow.interactionManager = new EditManager();
			textFlow.addEventListener(FlowOperationEvent.FLOW_OPERATION_END,
					flowOperationEndHandler);
		}
		
		protected function flowOperationEndHandler(event:FlowOperationEvent):void
		{
			SizeTextToContainerUtil.sizeTextToContainer(textFlow);
		}
	}
}