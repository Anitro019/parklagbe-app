import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/datetime_utils.dart';
import '../../data/models/booking.dart';
import '../../data/models/parking_spot.dart';
import '../../data/models/user_profile.dart';

class PdfReceiptService {
  /// Generate PDF Document bytes for a booking
  static Future<Uint8List> buildReceiptPdf({
    required Booking booking,
    required ParkingSpot spot,
    UserProfile? customer,
    UserProfile? owner,
  }) async {
    final pdf = pw.Document(title: 'ParkLagbee Receipt ${booking.bookingReference}');

    final bdDateStr = DateTimeUtils.formatBdDate(booking.bookingDate);
    final bdStartTimeStr = DateTimeUtils.formatBdTime(booking.startTime);
    final bdEndTimeStr = DateTimeUtils.formatBdTime(booking.endTime);

    final subtotal = booking.totalPrice;
    final advance = booking.advanceAmount;
    final dueOnArrival = subtotal - advance;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Header & Brand Banner
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PARKLAGBEE',
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                      pw.Text(
                        'Parking Rental & Booking in Bangladesh',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: _getStatusColor(booking.bookingStatus),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      booking.bookingStatus.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 16),

              // 2. Reference & Date Generated
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Booking Reference: ${booking.bookingReference}',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Generated: ${DateTimeUtils.formatBdDateTime(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // 3. Customer & Spot Owner Information
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('RENTER / CUSTOMER', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                          pw.SizedBox(height: 4),
                          pw.Text(customer?.fullName ?? 'ParkLagbee Renter', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          if (customer?.phone != null) pw.Text('Phone: ${customer!.phone}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('SPOT OWNER / HOST', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                          pw.SizedBox(height: 4),
                          pw.Text(owner?.fullName ?? 'Parking Space Host', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          if (spot.isContactVisible && spot.contactPhone != null)
                            pw.Text('Phone: ${spot.contactPhone}', style: const pw.TextStyle(fontSize: 10))
                          else
                            pw.Text('Contact details available upon confirmation', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // 4. Parking Spot & Location
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PARKING SPOT LOCATION', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                    pw.SizedBox(height: 4),
                    pw.Text(spot.title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('${spot.address}, ${spot.area}, ${spot.district}', style: const pw.TextStyle(fontSize: 11)),
                    if (spot.googleMapsUrl != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('Google Maps: ${spot.googleMapsUrl}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue700)),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // 5. Booking Schedule & Vehicle Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Booking Date', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Time Window', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Duration', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Vehicle Type', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(bdDateStr, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$bdStartTimeStr - $bdEndTimeStr', style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${booking.durationHours.toStringAsFixed(1)} hrs', style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${booking.vehicleType.toUpperCase()} ${booking.vehicleNumber != null ? "(${booking.vehicleNumber})" : ""}', style: const pw.TextStyle(fontSize: 10))),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // 6. Pricing & Advance Breakdown Table
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.teal700, width: 1),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfPriceRow('Total Rental Cost:', 'BDT ${subtotal.toStringAsFixed(2)}', isBold: true),
                    pw.SizedBox(height: 4),
                    _buildPdfPriceRow('Advance Required (${spot.advanceRequirementPercentage.toStringAsFixed(0)}%):', 'BDT ${advance.toStringAsFixed(2)}'),
                    pw.SizedBox(height: 4),
                    _buildPdfPriceRow('Balance Due on Arrival:', 'BDT ${dueOnArrival.toStringAsFixed(2)}', isBold: true),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // 7. Payment Arrangement Notice
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  border: pw.Border.all(color: PdfColors.amber400),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PAYMENT ARRANGEMENT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Payment is arranged directly between customer and parking owner via Cash, direct bKash/Nagad, or bank transfer upon arrival.',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),

              // 8. MANDATORY LEGAL DISCLAIMER
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'DISCLAIMER: ParkLagbee does not process, collect, hold, transfer, or verify payments. Please confirm payment directly with the parking owner. Never transfer money without verifying parking space access.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Download or share receipt PDF file
  static Future<void> printOrShareReceipt({
    required Booking booking,
    required ParkingSpot spot,
    UserProfile? customer,
    UserProfile? owner,
  }) async {
    final pdfBytes = await buildReceiptPdf(
      booking: booking,
      spot: spot,
      customer: customer,
      owner: owner,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'ParkLagbee_Receipt_${booking.bookingReference}.pdf',
    );
  }

  static PdfColor _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'active':
        return PdfColors.green700;
      case 'completed':
        return PdfColors.blue700;
      case 'cancelled':
      case 'rejected':
        return PdfColors.red700;
      default:
        return PdfColors.orange700; // 'pending'
    }
  }

  static pw.Widget _buildPdfPriceRow(String label, String value, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }
}
