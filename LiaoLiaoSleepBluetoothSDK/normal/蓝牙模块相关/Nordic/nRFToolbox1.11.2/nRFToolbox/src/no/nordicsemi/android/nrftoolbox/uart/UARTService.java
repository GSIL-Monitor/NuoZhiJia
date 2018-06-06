package no.nordicsemi.android.nrftoolbox.uart;

import no.nordicsemi.android.log.ILogSession;
import no.nordicsemi.android.log.Logger;
import no.nordicsemi.android.nrftoolbox.FeaturesActivity;
import no.nordicsemi.android.nrftoolbox.R;
import no.nordicsemi.android.nrftoolbox.profile.BleManager;
import no.nordicsemi.android.nrftoolbox.profile.BleProfileService;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.IBinder;
import android.support.v4.content.LocalBroadcastManager;

public class UARTService extends BleProfileService implements UARTManagerCallbacks {
	public static final String BROADCAST_UART_TX = "no.nordicsemi.android.nrftoolbox.uart.BROADCAST_UART_TX";
	public static final String BROADCAST_UART_RX = "no.nordicsemi.android.nrftoolbox.uart.BROADCAST_UART_RX";
	public static final String EXTRA_DATA = "no.nordicsemi.android.nrftoolbox.uart.EXTRA_DATA";

	private final static String ACTION_DISCONNECT = "no.nordicsemi.android.nrftoolbox.uart.ACTION_DISCONNECT";

	private final static int NOTIFICATION_ID = 349; // random
	private final static int OPEN_ACTIVITY_REQ = 67; // random
	private final static int DISCONNECT_REQ = 97; // random

	private UARTManager mManager;
	private boolean mBinded;

	private final LocalBinder mBinder = new UARTBinder();

	public class UARTBinder extends LocalBinder implements UARTInterface {
		@Override
		public void send(final String text) {
			mManager.send(text);
		}

		@Override
		public ILogSession getLogSession() {
			return super.getLogSession();
		}
	}

	@Override
	protected LocalBinder getBinder() {
		return mBinder;
	}

	@Override
	protected BleManager<UARTManagerCallbacks> initializeManager() {
		return mManager = new UARTManager(this);
	}

	@Override
	public void onCreate() {
		super.onCreate();

		final IntentFilter filter = new IntentFilter();
		filter.addAction(ACTION_DISCONNECT);
		registerReceiver(mDisconnectActionBroadcastReceiver, filter);
	}

	@Override
	public void onDestroy() {
		// when user has disconnected from the sensor, we have to cancel the notification that we've created some milliseconds before using unbindService
		cancelNotification();
		unregisterReceiver(mDisconnectActionBroadcastReceiver);

		super.onDestroy();
	}

	@Override
	public IBinder onBind(final Intent intent) {
		mBinded = true;
		return super.onBind(intent);
	}

	@Override
	public void onRebind(final Intent intent) {
		mBinded = true;
		// when the activity rebinds to the service, remove the notification
		cancelNotification();
	}

	@Override
	public boolean onUnbind(final Intent intent) {
		mBinded = false;
		// when the activity closes we need to show the notification that user is connected to the sensor  
		createNotifcation(R.string.uart_notification_connected_message, 0);
		return super.onUnbind(intent);
	}

	@Override
	public void onDataReceived(final String data) {
		Logger.a(getLogSession(), "\"" + data + "\" received");

		final Intent broadcast = new Intent(BROADCAST_UART_RX);
		broadcast.putExtra(EXTRA_DATA, data);
		LocalBroadcastManager.getInstance(this).sendBroadcast(broadcast);
	}

	@Override
	public void onDataSent(String data) {
		Logger.a(getLogSession(), "\"" + data + "\" sent");

		final Intent broadcast = new Intent(BROADCAST_UART_TX);
		broadcast.putExtra(EXTRA_DATA, data);
		LocalBroadcastManager.getInstance(this).sendBroadcast(broadcast);
	}

	/**
	 * Creates the notification
	 * 
	 * @param messageResIdthe
	 *            message resource id. The message must have one String parameter,<br />
	 *            f.e. <code>&lt;string name="name"&gt;%s is connected&lt;/string&gt;</code>
	 * @param defaults
	 *            signals that will be used to notify the user
	 */
	private void createNotifcation(final int messageResId, final int defaults) {
		final Intent parentIntent = new Intent(this, FeaturesActivity.class);
		parentIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
		final Intent targetIntent = new Intent(this, UARTActivity.class);

		final Intent disconnect = new Intent(ACTION_DISCONNECT);
		final PendingIntent disconnectAction = PendingIntent.getBroadcast(this, DISCONNECT_REQ, disconnect, PendingIntent.FLAG_UPDATE_CURRENT);

		// both activities above have launchMode="singleTask" in the AndoridManifest.xml file, so if the task is already running, it will be resumed
		final PendingIntent pendingIntent = PendingIntent.getActivities(this, OPEN_ACTIVITY_REQ, new Intent[] { parentIntent, targetIntent }, PendingIntent.FLAG_UPDATE_CURRENT);
		final Notification.Builder builder = new Notification.Builder(this).setContentIntent(pendingIntent);
		builder.setContentTitle(getString(R.string.app_name)).setContentText(getString(messageResId, getDeviceName()));
		builder.setSmallIcon(R.drawable.ic_stat_notify_uart);
		builder.setShowWhen(defaults != 0).setDefaults(defaults).setAutoCancel(true).setOngoing(true);
		builder.addAction(R.drawable.ic_action_bluetooth, getString(R.string.uart_notification_action_disconnect), disconnectAction);

		final Notification notification = builder.build();
		final NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
		nm.notify(NOTIFICATION_ID, notification);
	}

	/**
	 * Cancels the existing notification. If there is no active notification this method does nothing
	 */
	private void cancelNotification() {
		final NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
		nm.cancel(NOTIFICATION_ID);
	}

	/**
	 * This broadcast receiver listens for {@link #ACTION_DISCONNECT} that may be fired by pressing Disconnect action button on the notification.
	 */
	private BroadcastReceiver mDisconnectActionBroadcastReceiver = new BroadcastReceiver() {
		@Override
		public void onReceive(final Context context, final Intent intent) {
			Logger.i(getLogSession(), "Disconnect action pressed");
			if (isConnected())
				getBinder().disconnect();
			else
				stopSelf();
		};
	};

}
